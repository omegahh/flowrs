## The stdlib

It gives you logging that lands in the right file, config access, validation helpers, and error
reporting that agrees with your manifest. It is available in four languages, and **in every one it
is loaded for you** — an author never writes the path.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Nothing to source: the helpers are already defined.
```

```python
#!/usr/bin/env python3
from flowrs import Context, Logger, get_config, die   # PYTHONPATH is already set
```

```r
#!/usr/bin/env Rscript
# Nothing to source: `library()` is not needed either, since the file is
# already loaded before your script's first line.
```

```cpp
#include "flowrs.hpp"   // -Istdlib/cpp -Istdlib/cpp/vendor; see the Makefile
```

### bash

**The helpers are available without sourcing anything.** The engine exports `BASH_ENV` pointing at
`stdlib/bash/flowrs.sh`, and non-interactive bash loads it before your script's first line — the
same courtesy `PYTHONPATH` does for Python. A step just calls `log_info`.

Sourcing the file by hand also works: a re-entry guard makes a second load return immediately.
Keep such a line only if the script must also run outside FlowRs, where nothing sets `BASH_ENV`.

The stdlib sets no shell options, so `set -euo pipefail` is yours to put in each step, as the
scaffolded `hello.sh` does — loaded through `BASH_ENV`, anything the stdlib `set`s would apply to
your whole script whether you chose it or not.

| Group      | Functions                                                                       |
| ---------- | ------------------------------------------------------------------------------- |
| Logging    | `log_info` `log_warn` `log_debug` `log_trace` `die`                             |
| Detectors  | `report_param` — for `bin/<detector>` only, see below                        |
| Config     | `get_config` `has_config` `get_config_int` `get_config_bool`                    |
| Validation | `require_file` `require_dir` `require_var` `require_command` `require_nonempty` |
| Commands   | `exec_cmd` `exec_cmd_silent` `exec_cmd_optional` `exec_with_retry`              |
| Sequence   | `get_fastq_prefix` `count_reads` `get_file_size` `looks_like_gzip`              |
| Health     | `gzip_health` `text_health` `fastq_health` `fasta_health` + probes |
| Timing     | `timestr` `elapsed_time` `benchmark`                                            |

```bash
quality=$(get_config "quality" 20)          # value, or the fallback
require_dir "${INPUT_DIR}" "input directory"
exec_with_retry 3 samtools index "${OUT_DIR}/aligned.bam"
log_info "done at quality ${quality}"
```

### Python

`Context.from_env()` wraps the environment; module-level functions cover the same ground.

```python
from flowrs import Context, Logger

ctx = Context.from_env()
log = Logger()

log.info(f"running {ctx.unit} for {ctx.taskid}")
quality = ctx.get_config("quality", default=20, cast=int)
ctx.require_dir(ctx.input_dir, "input directory")
(ctx.out_dir / "result.txt").write_text(f"quality={quality}\n")
log.info("done")
```

`Logger` has `info` `warn` `debug` `trace` `die` `benchmark`. Module level adds
`get_config` `has_config` `require_file` `require_dir` `require_command` `require_nonempty`
`require_var` `exec_cmd` `die`, plus sequence helpers: `read_fasta` `read_fastq`
`write_fasta` `parse_fai` `count_fastq_reads` `list_fastq_files` `revcomp` `complement`
`gc_content` `get_fastq_prefix`.

### Cross-language agreement

`get_fastq_prefix` is a **pair key**: both mates of a paired-end run must map to the same prefix,
and every language must agree on it — otherwise a bash step and a Python step disagree about which
files belong together. All four implementations are checked against one shared table of cases by
`tests/stdlib_fastq.rs`, so `sample_R1.fastq.gz` and `sample_R2.fastq.gz` both yield `sample`
everywhere.

### Reporting an error

`die` is the **only** helper that reports an error, in every language, because only the exit code
fails a step. So an error always has a consequence — either you `die` on it, or what you have is a
`log_warn`. Two forms; report a declared failure by **code**, never by number:

```bash
die NO_INPUT_DATA "nothing under ${INPUT_DIR}"   # an error NAME -> exits with its declared code
```

```bash
die "cannot open the reference" 3                # a message     -> exits 3 (default 1)
```

All four languages look the first argument up in `FLOWRS_ERROR_MAP` and exit with the declared
`exit_code`. `exit 20` would work too, but the number lives in the manifest — a step that hardcodes
it goes silently wrong the day someone renumbers.

**That lookup alone decides the form**, never capitalisation: an `UPPERCASE_NAME` you have not
declared reads as a plain message and exits `1`. If a `die` you expected to carry a declared code
exits `1`, check its spelling against `[[errors]]`. Pass a code *or* a message, never a name plus a
number — a name's code comes from the map, so a second numeric argument has nothing to mean.

In Python and R `die` is module-level; in C++ it is `log.die`. `Logger().die` forwards to it in
Python.

### Reporting a detected parameter

One more log helper exists, and it is for **detectors only** — a script named by some parameter's
`detector`. It writes the tagged line the engine reads that parameter's value from:

| Language | Helper                                          |
| -------- | ----------------------------------------------- |
| bash     | `report_param SEQTYPE TGSONT`                |
| Python   | `Logger().report_param("SEQTYPE", "TGSONT")` |
| R        | `report_param("SEQTYPE", "TGSONT")`          |
| C++      | `log.report_param("SEQTYPE", "TGSONT")`      |

It names the parameter because one script may answer for several — call it once per parameter.
Unlike every other helper it prints nothing to the console and is never silenced by `-q`, because
the line is data rather than a message. See the [manifest reference](manifest-reference.md#detector--a-computed-default) for the full
contract; calling it from a step does nothing.

### Checking input health

Four functions answer "is this input shaped the way my step assumes". They return **nothing when the
input is healthy** and a built-in error name when it is not, which makes the check one line:

```bash
err=$(fastq_health "${INPUT_DIR}/reads.fq.gz") || die "${err}"
```

That is `set -e` safe: on a healthy file `fastq_health` exits 0 and prints nothing, so the `||`
branch is not taken. The same shape in the other three languages:

```python
err = fastq_health(path)
if err:
    die(err)
```

```r
err <- fastq_health(path)
if (!is.null(err)) die(err)
```

```cpp
auto err = flowrs::fastq_health(path);
if (!err.empty()) log.die(err);
```

`gzip_health` checks the magic number, that the head decompresses, and that it was not gzipped
twice. `text_health` covers BOM, UTF-16, and null bytes. `fastq_health` and `fasta_health` add shape
on top of `text_health` and accept plain or gzipped input transparently.

**You declare nothing.** The names below are always in `FLOWRS_ERROR_MAP`, so `die` resolves them
with no `[[errors]]` section, they land in `status.json` with a default message and `category =
"input"`, and you can hook them:

```toml
[pipeline.hooks.on_error]
DOUBLE_GZIPPED = ["unwrap_and_retry.sh"]
```

| Code | Name | Meaning |
| ---- | ---- | ------- |
| 100 | `NOT_GZIP` | not gzip-compressed |
| 101 | `DOUBLE_GZIPPED` | gzipped twice |
| 102 | `UTF8_BOM` | leading UTF-8 byte-order mark |
| 103 | `UTF16_ENCODING` | UTF-16, either byte order |
| 104 | `CRLF_LINE_ENDINGS` | reserved; no health function reports it |
| 105 | `BINARY_CONTENT` | null bytes where text was expected |
| 106 | `BAD_FASTQ_SHAPE` | not FASTQ-shaped |
| 107 | `BAD_FASTA_SHAPE` | not FASTA-shaped |
| 108 | `UNREADABLE` | missing or unreadable |
| 109 | `INCOMPLETE_GZIP` | gzip stream ends before its data does — depth reads only |

You cannot declare an `[[errors]]` entry with one of these names, and cannot collide with their
numbers — your band stops at 63.

**By default these are head sniffs, not validators.** Each reads the first 64KB and stops, so a file
truncated or corrupt past the head passes. That is the downstream parser's job; the functions are
named `health` rather than `validate` to say so.

### Reading deeper than the head

When you want truncation caught, give `fastq_health` or `fasta_health` a record count:

```bash
err=$(fastq_health "${INPUT_DIR}/reads.fq.gz" 10000) || die "${err}"
```

```python
err = fastq_health(path, 10000)
```

```r
err <- fastq_health(path, 10000L)
```

```cpp
auto err = flowrs::fastq_health(path, 10000);
```

Omitting the count checks no record structure at all. With it, each record is checked structurally —
for FASTQ all four lines, with the quality string the same length as the sequence.

Three rules, the first mattering most in practice:

1. **Running out of records early is healthy.** A 100-record file passes `fastq_health f 10000`, so
   you can pick a generous number without special-casing small inputs.
2. **EOF in the middle of a record is a shape error** (`BAD_FASTQ_SHAPE` / `BAD_FASTA_SHAPE`) — the
   file does not contain what it says it does.
3. **A gzip stream that ends before its data does is `INCOMPLETE_GZIP`.** This outranks rule 2,
   because corruption often produces bytes that look like a malformed record, and blaming the record
   would send you to inspect data that was intact before the stream broke.

A depth read is cheap — 10000 reads is about 2MB, so milliseconds. Pick the count that makes you
confident. What it *cannot* see is a defect past that count; for whole-file integrity use `gzip -t`.

**CRLF is deliberately not a failure.** Most tools read it fine, and a health check reports by exit
code, so reporting it would fail runs over Windows-authored files that would otherwise have worked.
Use the probe when you actually care:

```bash
[[ "$(sniff_line_ending "${f}")" == crlf ]] && dos2unix "${f}"
```

The probes each health function is built from are public, for narrower questions: `read_head` ·
`looks_like_gzip` · `is_double_gzipped` · `sniff_line_ending` · `sniff_encoding` ·
`looks_like_fastq` · `looks_like_fasta`. `looks_like_gzip` reads the magic number, so it is right
about a gzipped `.fq`.

### Versioning

The scaffold version lives in `stdlib/bash/flowrs.sh` as `FLOWRS_STDLIB_VERSION`. `flowrs create
--update` reads it to decide whether a pipeline needs newer stdlib files.

---
