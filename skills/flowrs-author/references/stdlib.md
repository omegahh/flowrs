# Step, Detector, And Hook Scripts

Read this file before writing an executable. FlowRs runs each unit as a subprocess, captures stdout
and stderr in a log, and uses the process exit code as the result. A script may be a plain executable
that exits zero; the stdlib is optional.

## Unit Environment

FlowRs supplies the following variables to steps, detectors, and hooks:

| Variable | Meaning |
| --- | --- |
| INPUT_DIR | Input directory from -i; scripts must not modify it |
| OUT_DIR | Run output directory |
| TMP_DIR | Run scratch directory |
| LOG_DIR | Run log directory |
| WORK_DIR | Work directory from -w |
| FLOWRS_UNIT | Unit name |
| FLOWRS_UNIT_KIND | step, hook, or detector |
| THREADS | Threads granted to a step or detector; hooks receive 1 without holding a permit |
| FLOWRS_VERBOSITY | 0 through 3, from -q, normal, -v, and -vv |
| FLOWRS_ERROR_MAP | JSON map from error names to exit codes |

Before starting a unit, the engine sets OMP_NUM_THREADS, OMP_THREAD_LIMIT,
OPENBLAS_NUM_THREADS, MKL_NUM_THREADS, BLIS_NUM_THREADS, VECLIB_MAXIMUM_THREADS,
NUMEXPR_NUM_THREADS, NUMEXPR_MAX_THREADS, RAYON_NUM_THREADS, and POLARS_MAX_THREADS to THREADS.
It sets OMP_DYNAMIC and MKL_DYNAMIC to FALSE. These replace inherited values and apply before
library imports. They configure individual pools: divide THREADS among multiprocessing workers
and set each worker's native limits before imports. Tool flags and explicit pool settings must
also honour the grant.

These variables are present only when applicable:

| Variable | Condition |
| --- | --- |
| TASKID | -t was supplied |
| CACHE_DIR | pipeline.cache_dir is declared |
| ITEM_DIR | The step is one item of a scatter |
| FLOWRS_COLLECTION | The step scatters |
| FLOWRS_ITEM_ID | The step scatters |
| FLOWRS_ITEM_INDEX | The step scatters; zero-based collection order |
| FLOWRS_ITEM_FILE | The step scatters; JSON item metadata |
| FLOWRS_GATHER_MANIFEST | The step gathers; JSON list of collected instances |

Check optional variables before use. Do not assume a scattered item id is a safe path component.
Use ITEM_DIR for item outputs.

Resolved parameters are exported under uppercase names. Before a step runs, declared
parameters must have a supplied, resumed, detected, profile-default, or base-default value. Supply
-p or -c when no other tier provides a value.

The engine drops inherited variables whose names contain SECRET, TOKEN, PASSWORD, PASSWD,
CREDENTIAL, API_KEY, APIKEY, or PRIVATE_KEY, case-insensitively. Do not put secrets in parameters:
params.json records resolved values.

The current working directory is the directory from which flowrs was launched. Build paths from the
engine variables.

## Language Loading

- Bash: when the helper file exists, BASH_ENV loads stdlib/bash/flowrs.sh in non-interactive Bash. Use bash with set -euo pipefail.
- Python: PYTHONPATH includes stdlib/python and optional lib/python. Import flowrs.
- R: when the helper file exists, R_PROFILE_USER loads stdlib/r/flowrs.R unless startup options
  disable it. Use the functions directly in that setup.
- C++: write `#include "flowrs.hpp"`; compile with C++17, `-Istdlib/cpp`,
  `-Istdlib/cpp/vendor`, and `-lz`. The scaffold Makefile supplies these flags.

The pipeline bin directory is prepended to PATH. Python and R library directories are also added
when present.

## Logging

Emit a tagged line on stderr:

~~~text
[FLOWRS:INFO] message
~~~

Accepted levels are INFO, WARN, ERROR, DEBUG, and TRACE. INFO, WARN, and ERROR show at normal
verbosity; DEBUG requires -v; TRACE requires -vv. -q suppresses all tagged narration. The raw line
remains in the unit log.

Use these helpers:

| Language | Logging |
| --- | --- |
| Bash | log_info, log_warn, log_debug, log_trace |
| Python | Logger().info, warn, debug, trace |
| R | log_info, log_warn, log_debug, log_trace |
| C++ | flowrs::Logger methods info, warn, debug, trace |

Do not use a log tag as the only failure signal. Use a nonzero exit or `die` to fail the script;
missing declared outputs also fail the step after exit 0.

## Errors

Declare author errors in the manifest with codes in 1 through 63. Report by code:

~~~bash
die NO_INPUT_DATA "no reads under $INPUT_DIR"
~~~

The stdlib looks the first argument up in FLOWRS_ERROR_MAP. If found, it exits with the mapped
code. Otherwise the first argument is a message and the optional second argument is an integer exit
code; the default is 1.

| Language | Error call |
| --- | --- |
| Bash | die CODE MESSAGE |
| Python | die("CODE", "MESSAGE") |
| R | die("CODE", "MESSAGE") |
| C++ | log.die("CODE", "MESSAGE") |

Use the declared code name rather than a hard-coded number. A typo in an undeclared uppercase name becomes a
plain message and exits 1.

## Detectors

A detector is a file in bin/ named by a parameter's detector field. It receives -i INPUT_DIR and
-o OUT_DIR flags. Parse flags; do not assume positional arguments. It sees unit environment variables
but not resolved parameters.

Report each answer on stderr:

~~~text
[FLOWRS:PARAM] PARAM_NAME=value
~~~

Use report_param in Bash, Logger().report_param in Python, report_param in R, and
`log.report_param("NAME", "value")` on a `flowrs::Logger` in C++. One detector may answer several named parameters. Answer each parameter
once. Stdout is not read for values. A duplicate or invalid answer fails resolution. A detector that
reports nothing uses the parameter's declared default when one exists; without a default, resolution fails.

Explicit or resumed values bypass detection for that parameter; a script shared by other unsupplied
parameters may still run. Nonzero exits and timeouts fail even with a base default. A detector result is
validated against type, enum, and bounds before any step starts.

## Hooks

Hooks are units with FLOWRS_UNIT_KIND=hook. They receive the same paths and logging helpers.
They run asynchronously: do not use `on_start` to prepare files steps need. Detectors and `on_start`
receive no resolved parameters. Later hooks use resolved parameters when resolution succeeded.
Outcome variables depend on the hook phase:

| Variable | Supplied to |
| --- | --- |
| EXIT_CODE | on_success as 0; on_failure when known |
| FAILED_STEP | on_failure when a step failed |
| ERROR_CODE | on_error, with the resolved error name |
| CANCELLED | on_failure as 1 when a signal cancelled the run |
| CANCELLED_BY | on_failure with the cancellation signal number |

These hook outcome names are reserved parameter names. Only the current phase supplies their values;
absent fields are not inherited from the invoking environment.

Hooks do not hold thread permits. Hook failure does not change the run result. Cancellation does not
trigger a new on_error hook; hooks already running are allowed to finish. The invocation waits for
started hooks before its final summary and scratch cleanup; each script has a five-minute timeout.
Missing scripts have skipped records; process launch failures only warn. Do not depend on hook
delivery. Use a teardown step when delivery failure must fail the run.

## Configuration

| Language | Configuration |
| --- | --- |
| Bash | get_config KEY DEFAULT, has_config KEY, get_config_int, get_config_bool |
| Python | get_config(key, default=None, cast=None), has_config, get_config_int, get_config_bool; Context.get_config |
| R | get_config, has_config, get_config_int, get_config_bool |
| C++ | `auto ctx = flowrs::Context::from_env();` then `ctx.get_config(key, fallback)`, `ctx.has_config(key)`, `ctx.get_config_int`, `ctx.get_config_num`, `ctx.get_config_bool` |

Parameter keys are case-insensitive and resolve to uppercase environment variables.
Config getters read the live environment, including Context.get_config/has_config in Python;
Context path attributes are snapshots from from_env().

- Bash get_config_bool is a status predicate that prints nothing: use if get_config_bool KEY; then.
  Do not compare its command-substitution output with true.
- Bash, R, and C++ boolean getters recognize true, 1, and yes case-insensitively; other non-empty
  values are false. Unset or empty values use the fallback.
- Python get_config_bool strips whitespace and recognizes 1/true/yes/y/on and 0/false/no/n/off.
  Unset or empty uses the fallback; other values raise ValueError.
- Python get_config_int (or cast=int) raises ValueError for malformed strings. Bash and C++ integer
  getters accept leading integer prefixes; R uses as.integer and can truncate numeric strings.
  Their integer fallbacks cover failed conversion, not strict whole-string validation.
- Generic get_config treats an empty value as missing in Bash/R and as an empty value in Python/C++.
  has_config is false for an unset or empty value in these languages.

## Validation And Commands

Use require_file, require_dir, require_var, require_command, and require_nonempty. R also provides
require_package.
Pass the value and a description in Bash, Python, and R. In C++, pass a Logger first:
`flowrs::require_file(log, path, "input file")`. `require_var` takes an environment variable name.

Use exec_cmd for a command whose output belongs in the unit log. Bash additionally provides
exec_cmd_silent, exec_cmd_optional, and exec_with_retry. Python, R, and C++ provide exec_cmd with a
check option. In C++, call `flowrs::exec_cmd(log, command, check)`. In Bash, exec_cmd returns the
child code; use `set -e` or handle the result.

## Sequence And Files

The common health and probe helpers exist in Bash, Python, R, and C++, but sequence and file helpers differ.
Use only the surface for the language of the unit:

| Language | Sequence and file helpers |
| --- | --- |
| Bash | `get_fastq_prefix`, `list_r1_files`, `list_r2_files`, `count_reads`, `get_file_size`, `join_by`, `array_contains` |
| Python | `count_fastq_reads`, `list_fastq_files` (glob pattern), `get_fastq_prefix`, `read_fastq`, `read_fasta`, `write_fasta`, `parse_fai`, `complement`, `revcomp`, `gc_content` |
| R | `get_fastq_prefix`, `list_files` (regular-expression pattern), `load_file`, `save_file`, `save_plot` |
| C++ | `get_fastq_prefix`, `list_fastq_files` (glob pattern) |

All four languages provide `read_head`, `looks_like_gzip`, `is_double_gzipped`,
`sniff_line_ending`, `sniff_encoding`, `looks_like_fastq`, and `looks_like_fasta`.
Python, R, and C++ also provide `read_lines`. Input-health helpers are listed below.
`timestr` and `elapsed_time` are available everywhere. Use `benchmark` in Bash or R,
`Logger.benchmark` in Python, and `flowrs::Benchmark` in C++.

## Input Health

Health helpers return an empty result when healthy and an error name when unhealthy:

| Code | Name | Meaning |
| --- | --- | --- |
| 100 | NOT_GZIP | Not gzip-compressed |
| 101 | DOUBLE_GZIPPED | Gzip-compressed twice |
| 102 | UTF8_BOM | UTF-8 BOM present |
| 103 | UTF16_ENCODING | UTF-16 input |
| 104 | CRLF_LINE_ENDINGS | Reserved; no health helper emits it |
| 105 | BINARY_CONTENT | Null bytes in text |
| 106 | BAD_FASTQ_SHAPE | Invalid FASTQ shape |
| 107 | BAD_FASTA_SHAPE | Invalid FASTA shape |
| 108 | UNREADABLE | Missing or unreadable |
| 109 | INCOMPLETE_GZIP | Truncated gzip stream; depth checks only |

Use gzip_health, text_health, fastq_health, and fasta_health, then pass a returned name to die.
Use the language's healthy-result check:

| Language | Call |
| --- | --- |
| Bash | `err=$(fastq_health "$path") || die "$err"` |
| Python | `err = fastq_health(path)`; `if err: die(err)` |
| R | `err <- fastq_health(path)`; `if (!is.null(err)) die(err)` |
| C++ | `auto err = flowrs::fastq_health(path); if (!err.empty()) log.die(err);` |

Without a record count, FASTQ and FASTA checks inspect the head. Pass a count to inspect records
deeply. A file ending before the requested count is healthy; an incomplete record is not.

## Outputs And Scatter

Write scalar outputs below OUT_DIR, or below CACHE_DIR when cached. Write scattered outputs below
ITEM_DIR even when cached; the engine selects the item's root. Declare output files in the step
manifest.

FLOWRS_ITEM_FILE contains id, index, key, and the source fields. FLOWRS_GATHER_MANIFEST lists the
instances a gather step must expect; item outcomes are in status.json.
