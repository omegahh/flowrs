# The stdlib

The scaffold supplies logging, config access, error reporting, command helpers, and input-health
checks for Bash, Python, R, and C++. The detailed API reference is `stdlib/CONTRACT.md`.

## Load the helpers

| Language | Setup |
| --- | --- |
| Bash | FlowRs sets `BASH_ENV` when `stdlib/bash/flowrs.sh` exists; non-interactive Bash loads it |
| Python | Import `flowrs`; FlowRs prepares `PYTHONPATH` |
| R | FlowRs sets `R_PROFILE_USER` when `stdlib/r/flowrs.R` exists; startup options can bypass it |
| C++ | Include `flowrs.hpp`; build with C++17, the stdlib include paths, and zlib |

Bash scripts choose their own shell options:

```bash
#!/usr/bin/env bash
set -euo pipefail
quality=$(get_config quality 20)
require_dir "$INPUT_DIR" "input directory"
log_info "quality=$quality"
printf '%s\n' "$quality" > "$OUT_DIR/result.txt"
```

Python:

```python
from flowrs import Context, Logger

ctx = Context.from_env()
log = Logger()
quality = ctx.get_config("quality", default=20, cast=int)
ctx.require_dir(ctx.input_dir, "input directory")
(ctx.out_dir / "result.txt").write_text(f"quality={quality}\n")
log.info("done")
```

R:

```r
quality <- get_config_int("quality", 20L)
log_info(paste("quality =", quality))
```

C++ builds need these options, or their Makefile equivalents:

```bash
g++ -std=c++17 -Istdlib/cpp -Istdlib/cpp/vendor sources/analyze.cpp -o steps/analyze -lz
```

## Config and logging

Config helpers read uppercase environment names. `get_config` accepts a fallback; typed helpers
also exist. Parsing differs by language, so validate unusual input explicitly rather than
assuming a malformed value falls back. Python integer and boolean getters raise `ValueError`
for malformed non-empty values.

In Bash, `get_config_bool` returns a shell status, not printed text:

```bash
if get_config_bool enabled false; then
  log_info "enabled"
fi
```

Logging helpers offer info, warn, debug, and trace. Messages go to execution logs; console
verbosity controls which are displayed. Use `die` to log an error and terminate.

## Report an error

For a declared `[[errors]]` code:

```bash
die NO_INPUT_DATA "nothing under $INPUT_DIR"
```

For an unclassified failure:

```bash
die "cannot open the reference" 3
```

The first argument selects the named form only when it matches `FLOWRS_ERROR_MAP`.
An undeclared name is treated as a message and defaults to exit 1. Prefer declared names over
hardcoded numbers. Python and R expose `die`; C++ uses `log.die`.

## Report a detected parameter

Detectors report answers to stderr with the `[FLOWRS:PARAM]` tag:

| Language | Helper |
| --- | --- |
| Bash | `report_param READ_LENGTH 250` |
| Python | `Logger().report_param("READ_LENGTH", "250")` |
| R | `report_param("READ_LENGTH", "250")` |
| C++ | `log.report_param("READ_LENGTH", "250")` |

Report a parameter once per detector execution. Steps do not use this channel for parameter
resolution. See [Detectors](manifest-reference.md#detector--a-computed-default).

## Check input health

Health helpers return no error for healthy input and a built-in error name otherwise:

```bash
err=$(fastq_health "$INPUT_DIR/reads.fq.gz") || die "$err"
```

```python
from flowrs import fastq_health, die

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

`gzip_health` checks gzip magic, head decompression, and double compression.
`text_health` checks encoding and null bytes. `fastq_health` and `fasta_health` add format sniffing
for plain or gzipped input. Built-in health codes need no `[[errors]]` declaration; see
[Exit codes](exit-codes.md#built-in-input-health-codes).

Default checks inspect a 64 KiB head and can miss later corruption. To check record structure
more deeply, supply a record count:

```bash
err=$(fastq_health "$INPUT_DIR/reads.fq.gz" 10000) || die "$err"
```

An input with fewer complete records is healthy; a partial record is a shape error.
A truncated gzip stream encountered during a depth read reports `INCOMPLETE_GZIP`.
Defects beyond the inspected records can still escape detection; use `gzip -t` for gzip
whole-stream integrity. CRLF alone is not a health failure.

Sequence helpers include FASTQ pairing prefixes. For example, `sample_R1.fastq.gz` and
`sample_R2.fastq.gz` both map to `sample` in the four languages.

## Update supplied files

Use `flowrs create PIPELINE --update` to refresh supplied stdlib files.
Keep your pipeline's scripts and libraries separate from those files.
