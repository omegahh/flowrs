# FlowRs

**Fast, safe workflow orchestration for computational pipelines**

FlowRs is a general-purpose pipeline orchestration system that executes DAG-based workflows defined in TOML manifests. It features parallel step execution, cooperative signal handling, typed parameter resolution with profile-aware defaults, and a bundled standard library for bash, Python, R, and C++ scripts. Originally designed for bioinformatics workflows, FlowRs is suitable for any computational pipeline requiring reproducible, parallel execution.

A pipeline is a directory of plain text and scripts, and every failure mode has a code. That makes FlowRs a good target for **automated authoring** — by a code generator, a CI template, or an LLM agent. See [Machine-Friendly by Design](#machine-friendly-by-design).

## Features

- ✅ **DAG-based execution** — automatic parallelization of independent steps
- ✅ **Type-safe parameters** — integer, number, string, boolean with `min`/`max`/`enum` validation
- ✅ **Profile-aware defaults** — pipeline-defined profile selects per-profile param defaults
- ✅ **Cross-parameter constraints** — `when`/`require` expressions validated after resolution
- ✅ **Trigger rules** — Airflow-style `all_success` / `one_failed` / `always` / etc.
- ✅ **Error taxonomy** — exit-code-based error codes with retry policies and per-error hooks
- ✅ **Lifecycle hooks** — on_start, on_success, on_failure, and per-error-code hooks
- ✅ **Multi-language stdlib** — bash, Python, R, and C++ (header-only)
- ✅ **Signal handling** — graceful cancellation with process-group cleanup
- ✅ **Scaffold system** — `flowrs create` bundles a stdlib into each pipeline
- ✅ **License system** — RSA-2048 signatures with NTP-backed clock-tamper detection
- ✅ **Registry** — name-based pipeline lookup at `~/.flowrs/registry.toml`
- ✅ **Declared outputs** — a step that exits 0 without writing them fails as `MISSING_OUTPUT`
- ✅ **Machine-readable output** — JSON/YAML from `run`, `list`, and `inspect`; published JSON Schema for `manifest.toml`
- ✅ **Shell completions** — bash, zsh, and fish completions included
- ✅ **Cross-run cache** — steps keyed on their inputs reuse results across runs
- ✅ **Resume support** — pick up failed pipelines with version safety checks
- ✅ **Dry-run mode** — preview the execution plan without running

## Installation

FlowRs ships as a pre-built, statically-linked binary — no toolchain or dependencies required.

```bash
# Linux x86_64
curl -LO https://github.com/omegahh/flowrs/releases/latest/download/flowrs-linux-x86_64.tar.gz
tar xzf flowrs-linux-x86_64.tar.gz
./flowrs --help
```

Verify the download against its published checksum:

```bash
sha256sum -c flowrs-linux-x86_64.tar.gz.sha256
```

Move the `flowrs` binary somewhere on your `PATH` (e.g. `/usr/local/bin`) to use it from anywhere. Browse all versions on the [Releases page](https://github.com/omegahh/flowrs/releases).

### Shell Completions

Release archives include shell completions in the `completions/` directory:

```bash
# Bash (system-wide)
sudo cp completions/flowrs.bash /etc/bash_completion.d/flowrs

# Zsh (user)
mkdir -p ~/.zsh/completion
cp completions/_flowrs ~/.zsh/completion/
# Add to ~/.zshrc: fpath=(~/.zsh/completion $fpath)

# Fish (user)
cp completions/flowrs.fish ~/.config/fish/completions/
```

## Quick Start

```bash
# Create a new pipeline
flowrs create my_pipeline

# Inspect it
flowrs inspect ./my_pipeline

# Run it
flowrs run ./my_pipeline -i /path/to/input -w /path/to/work -t task001

# Inspect the plan without running (steps, layers, params, tool presence)
flowrs inspect ./my_pipeline --check-environment
```

## Pipeline Structure

A pipeline is a self-contained directory:

```
my_pipeline/
├── manifest.toml        # Pipeline definition
├── steps/               # Step executables (.sh / .py / .R / compiled)
├── stdlib/              # Bundled standard library
│   ├── bash/
│   ├── python/
│   ├── r/
│   └── cpp/             # Header-only flowrs.hpp + vendored helpers
├── lib/                 # Custom shared libraries
├── sources/             # C/C++ source code (built into steps/ via Makefile)
├── bin/                 # Helper tools, e.g. profile detectors
└── tests/               # Test fixtures
```

### Manifest Example

```toml
[pipeline]
name = "my_pipeline"
version = "1.0"
min_threads = 4   # optional: refuse to run with fewer

# Pipeline-defined profile drives profile-specific param defaults
[pipeline.profile]
param = "SEQTYPE"
detector = "detect_seqtype.sh"   # script in bin/

[pipeline.profile.profiles]
ngs = ["PAIRED", "SINGLE"]
tgs = ["TGSONT"]

[steps.qc]
exec = "qc.sh"
label = "Quality control"

[steps.align]
exec = "align.sh"
label = "Alignment"
depends_on = ["qc"]
threads = 8                  # fixed; or "auto" to inherit --threads
outputs = ["${OUT_DIR}/aligned.bam"]   # missing after exit 0 → MISSING_OUTPUT failure

[steps.analyze]
exec = "analyze.py"
label = "Statistical analysis"
depends_on = ["align"]
trigger_rule = "all_success" # default; see Trigger Rules below

[params.SEQTYPE]
type = "string"
default = "PAIRED"
enum = ["PAIRED", "SINGLE", "TGSONT"]

[params.threads]
type = "integer"
default = 8
min = 1
max = 128
description = "Number of threads"

[params.min_quality]
type = "integer"
default = 20
min = 0
max = 40
description = "Minimum quality score"

# Profile-specific defaults
[params.threshold]
type = "number"
default = 0.5
[params.threshold.ngs]
default = 0.8
[params.threshold.tgs]
default = 0.3

# Cross-parameter constraints
[[constraints]]
when = "LIMIT_MEM > 0"
require = "SHARE_MEM == false"
message = "SHARE_MEM must be false when LIMIT_MEM is set"
```

Steps form a DAG via `depends_on`. Steps without mutual dependencies run in parallel.

### Script Example

Scripts use the bundled stdlib for common operations.

**Bash:**

```bash
#!/usr/bin/env bash
set -euo pipefail
# The stdlib helpers need no sourcing: the engine exports BASH_ENV.

log_info "Starting QC step"

threads=$(get_config_int "THREADS" "8")
min_quality=$(get_config_int "MIN_QUALITY" "20")

require_file "${INPUT_DIR}/sample.fastq.gz" "Input FASTQ"
require_command "fastp" "fastp tool"

exec_cmd "fastp -i input.fq -o output.fq -w ${threads} -q ${min_quality}" "fastp.log"

log_success "QC completed"
```

**Python:**

```python
#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent / "stdlib" / "python"))

from flowrs import Context, Logger, get_config, require_file

ctx = Context.from_env()

with Logger(ctx.log_dir / "analyze.log") as log:
    log.info("Starting analysis")
    threads = get_config("THREADS", default=8, cast=int)
    require_file(ctx.out_dir / "alignments.bam", "BAM file")
    log.success("Analysis completed")
```

**R:**

```r
#!/usr/bin/env Rscript
script_dir <- dirname(sys.frame(1)$ofile)
source(file.path(script_dir, "..", "stdlib", "r", "flowrs.R"))

log_info("Starting visualization")
threads <- get_config("THREADS", default = 8, cast = as.integer)
require_file(file.path(OUT_DIR, "results.tsv"), "Results file")

data <- load_file(file.path(OUT_DIR, "results.tsv"))
library(ggplot2)
p <- ggplot(data, aes(x, y)) + geom_point()
save_plot(p, file.path(OUT_DIR, "plot.pdf"))

log_success("Visualization completed")
```

**C++:**

```cpp
// sources/qc.cpp — compiled into steps/qc by `make` in the scaffold
#include "flowrs.hpp"

int main(int argc, char** argv) {
    flowrs::Context ctx = flowrs::Context::from_env();
    flowrs::Logger log(ctx.log_dir / "qc.log");

    auto threads = flowrs::get_config<int>("THREADS", 8);
    flowrs::require_file(ctx.input_dir / "sample.fastq.gz", "Input FASTQ");

    log.info("QC completed");
    return 0;
}
```

Compile flags: `-std=c++17 -Istdlib/cpp -Istdlib/cpp/vendor -lz`. Vendored headers: `clipp.h` (arg parsing) and `kseqpp/` (FASTA/FASTQ reading).

## CLI Reference

```bash
# Global flags (available on all commands)
-q, --quiet                      Suppress all output except errors
-v, --verbose                    Increase verbosity (repeatable: -v, -vv)

# Pipeline execution
flowrs run <PIPELINE> -i DIR -w DIR [OPTIONS]
    -i, --input-dir <DIR>        Input directory (read-only; never written to)
    -w, --work-dir <DIR>         Workspace: everything the run writes goes here
    -t, --task-id <ID>           Optional task ID (3-64 chars, [A-Za-z0-9_-]). Given:
                                 outputs go to WORK_DIR/TASK_ID/, so several runs can
                                 share a workspace. Omitted: outputs go to WORK_DIR/
    -c, --config <FILE>          Config file: JSON, TOML, or KEY=VALUE (.env style); detected by extension
    -p, --param <KEY=VALUE>      Inline param override; repeatable
    -@, --threads <N>            Thread budget shared by all concurrent work (default: CPU count)
    -s, --start-step <STEP>      Start from a specific step
    -e, --end-step <STEP>        End at a specific step
    -k, --skip-steps <STEP>...   Skip specific steps
    --keep-tmp                   Keep temporary files after the run completes
    --tmp-dir <PATH>             Override the base temporary directory location

# Pipeline management
flowrs create <NAME> [-d DESC] [--update]
                                  Scaffold a new pipeline (or update its bundled stdlib)
flowrs compile <DIR> [--check] [-o OUT] [--encrypt] [--author NAME]
                                  Validate and optionally package/encrypt a pipeline into .flowpkg
flowrs inspect <PIPELINE> [--format FORMAT]
                                  Display steps, DAG, params, constraints, errors, hooks
flowrs register <PATH> [--name N] Register a pipeline for name-based lookup
flowrs unregister <NAME>          Remove a registered pipeline
flowrs list [--detailed] [--format FORMAT]
                                  List registered pipelines

# License management
flowrs license status [-f FILE]   Show license status with cryptographic validation
flowrs license add <FILE>         Install a license file to ~/.flowrs/license.json
flowrs license fingerprint        Show machine fingerprint for license requests
```

### Machine-Readable Output

The `list` and `inspect` commands support `--format` for structured output. `run` has no
`--format`: it writes `status.json` incrementally as the run proceeds, which is a strictly
better record than a single dump on exit.

```bash
# Get pipeline info as JSON
flowrs inspect my_pipeline --format json | jq '.steps'

# List registered pipelines as YAML
flowrs list --detailed --format yaml

# Check if a pipeline exists programmatically
flowrs list --format json | jq -r '.pipelines[] | select(.name=="mypipe") | .exists'

# Run, then consume status.json: per-step status, exit codes, and durations
flowrs run my_pipeline -i ./data -w ./work -t task001
jq '.steps[] | select(.status=="failed")' ./work/task001/status.json
```

## Machine-Friendly by Design

A FlowRs pipeline is a directory of TOML and scripts with no build step and no runtime graph
construction, so writing one is a file-authoring task. Several properties make that tractable for
a program — a code generator, a CI template, or an LLM agent — rather than only for a human:

**Mistakes fail loudly, not silently.** The manifest uses `deny_unknown_fields`, so an invented
field like `dependencies = [...]` instead of `depends_on` is a hard error naming the offending
key, not a setting that is quietly ignored. Combined with the DAG cycle check and the
"executable exists" check, `flowrs compile` is a single command that either accepts a generated
pipeline or explains what is wrong with it.

**A schema constrains generation up front.** `schema/manifest-v1.json` is generated from the Rust
types, so it never drifts from what the parser accepts. Point an editor or a
constrained-generation library at it:

```
https://raw.githubusercontent.com/omegahh/flowrs/main/schema/manifest-v1.json
```

**Every outcome is structured.** `<out>/status.json` carries per-step status, exit codes, and
durations, along with a `resolved_error` object for each failure, and is rewritten after every
state transition so a watcher can poll it mid-run. Nothing has to be recovered by scraping log
text.

**Failures are classified, not just reported.** Exit codes 1–63 belong to the pipeline author's
own `[[errors]]` taxonomy, so a step can report `LOW_COVERAGE` rather than "exit 1", and the code
survives into `status.json`. The engine reserves its own band — `120` `MISSING_OUTPUT`, `124`
`TIMEOUT`, `126`/`127` exec failures, `128+N` signals — and the CLI uses `64` (bad invocation),
`65` (malformed input), `70` (runtime), `77` (license), `78` (bad manifest). Because the bands are
disjoint, an exit code alone distinguishes "the tool refused" from "the pipeline reported a domain
error", and among the CLI's own codes it says which of them to go fix.

**Silent success is detectable.** Declaring `outputs` on a step converts "exited 0 but wrote
nothing" into a real failure with the `MISSING_OUTPUT` code. This is the failure mode automated
authoring hits most: a script whose logic is wrong but whose exit status is clean.

**Plans are inspectable before they run.** `flowrs inspect` prints steps, execution layers,
trigger rules, declared parameters, and constraints without executing anything, so a generated
pipeline can be checked for shape before it touches data. `--format json` gives the same
structure as data, and `--check-environment` additionally verifies the required tools resolve.

A practical authoring loop:

```bash
flowrs create my_pipeline              # scaffold with a stdlib and a working example
# ... generate manifest.toml and steps/ ...
flowrs compile ./my_pipeline           # validate: schema, DAG, script presence
flowrs inspect ./my_pipeline --check-environment   # steps, layers, params, tool presence
flowrs run ./my_pipeline -i ./data -w ./work -t smoke001
```

One current rough edge, to be clear about what is not yet structured: manifest validation errors
are human-readable prose rather than machine-parseable diagnostics. They are surfaced on stderr
with a distinguishing exit code (`78` for a bad manifest, `64` for a bad invocation), so a caller
can tell *that* validation failed and show the message, but not enumerate the failures as data.

There is also no invocation-specific preview: nothing reports which steps `-s`/`-e` would select
or what `-p`/`-c` resolve to. `flowrs inspect` answers the static half.

## Standard Library

Each scaffold bundles a stdlib copied into the pipeline directory:

**Bash (`stdlib/bash/flowrs.sh`)** — available without sourcing; the engine points `BASH_ENV` at it:

- Logging: `log_info`, `log_warn`, `log_error`, `log_success`, `log_debug`, `die`
- Validation: `require_file`, `require_dir`, `require_var`, `require_command`
- Config: `get_config`, `get_config_int`, `get_config_bool`
- Execution: `exec_cmd`, `exec_cmd_silent`, `exec_with_retry`
- File utils: `get_fastq_prefix` (pairing key — R1 and R2 give the same value),
  `list_r1_files`, `count_reads`
- Time: `timestr`, `elapsed_time`, `benchmark`

**Python (`stdlib/python/flowrs.py`):**

- `Context.from_env()` — runtime context
- `Logger` — logging with context manager
- `get_config()` — config with type casting
- `require_file/dir/command()` — validation
- `exec_cmd()` — shell command execution
- FASTQ utilities, time utilities

**R (`stdlib/r/flowrs.R`):**

- Logging functions
- Validation functions
- `get_config()` with type casting
- Smart I/O: `load_file()`, `save_file()`, `save_plot()`
- `get_fastq_prefix()` — pairing key, vectorized over a file list
- Time utilities

**C++ (`stdlib/cpp/flowrs.hpp`, header-only):**

- `flowrs::Context::from_env()` — runtime context (mirrors Python)
- `flowrs::Logger` — RAII logger
- `flowrs::get_config<T>()`, `flowrs::require_file/dir/command()`
- File and time utilities matching the bash/python/R interface

## Error Taxonomy & Retry Logic

FlowRs uses an exit-code-based error model with automatic retry policies and per-error hooks.

### Defining Error Codes

Each `[[errors]]` entry declares a unique `exit_code` in the range 1–63. Everything from 64 up belongs to FlowRs itself — 64/65/70/77/78 for the CLI's own bad-invocation, malformed-input, runtime, license, and bad-manifest failures, 100–125 for engine built-ins including the timeout sentinel 124 → `TIMEOUT`, 126/127 for exec failures, and 128+N for signal termination. The manifest fails validation if an author claims a reserved code or duplicates an `exit_code`, which keeps a declared pipeline error always distinguishable from a FlowRs failure.

```toml
[[errors]]
code = "NO_INPUT_DATA"
exit_code = 10
severity = "error"
category = "validation"
message = "Required input files not found"
retryable = false

[[errors]]
code = "NETWORK_TIMEOUT"
exit_code = 11
severity = "error"
category = "runtime"
message = "Remote resource unreachable"
retryable = true
max_retries = 3
```

Messages are static — there is no `{placeholder}` interpolation.

### Reporting Errors

A step reports an error by calling the stdlib `die("CODE")`, which looks up the code in the `FLOWRS_ERROR_MAP` env var (injected by the engine) and exits with the declared exit code. The engine maps the child's exit code back to the `[[errors]]` definition, records a `resolved_error` in `status.json`, drives retry (`retryable`/`max_retries`), and fires `on_error[CODE]` hooks.

`die` has two forms, told apart by that lookup: a first argument found in the map is an error code (the optional second argument is the message), and otherwise it is the message itself (the optional second argument is the exit code, default 1).

**Bash:**

```bash
die "NO_INPUT_DATA"
```

**Python:**

```python
from flowrs import die
die("NETWORK_TIMEOUT")
```

**R:**

```r
die("LOW_COVERAGE")
```

### Built-in Errors

The engine resolves unmapped exit codes to built-in, fatal errors that flow through the same path (so OOM/timeout/signal kills are catchable via `on_error`):

- `120` → `MISSING_OUTPUT` (step exited 0 without writing its declared `outputs`)
- `124` → `TIMEOUT`
- `126` → `NOT_EXECUTABLE`
- `127` → `COMMAND_NOT_FOUND`
- `128+N` → signal errors (`SIGINT`=130, `SIGABRT`=134, `SIGKILL`=137, `SIGSEGV`=139, `SIGTERM`=143; generic `SIGNAL` otherwise)
- any other unmapped non-zero code → `UNKNOWN_ERROR`

Profile detector failures resolve the same way, so `on_error`/`on_failure` hooks fire even when a detector fails before the engine starts.

### Lifecycle Hooks

Execute custom scripts at key pipeline events:

```toml
[pipeline.hooks]
on_start = ["setup_env.sh"]
on_success = ["notify_success.sh", "cleanup.sh"]
on_failure = ["notify_failure.sh", "save_logs.sh"]

[pipeline.hooks.on_error]
NO_INPUT_DATA = ["alert_missing_data.sh"]
NETWORK_TIMEOUT = ["retry_with_backoff.sh"]
```

Hooks receive environment variables:

- `on_failure`: `FAILED_STEP`, `EXIT_CODE`
- `on_error`: `ERROR_CODE`, plus the resolved error's `exit_code`

All hooks run to completion even if one fails, ensuring cleanup and notifications always execute.

## Execution Model

FlowRs automatically parallelizes independent steps based on the dependency graph:

1. Validates the pipeline manifest
2. Resolves parameters (command-line overrides > config file > profile defaults > base defaults)
3. Builds a dependency graph and checks for cycles
4. Executes steps in parallel where possible
5. Handles failures according to trigger rules
6. Writes results and status to the output directory

## Workspace Layout

`-i` is read-only input; `-w` is the workspace, and everything the run writes lives inside
it. FlowRs refuses to run if `-w` is inside `-i`.

```
{work_dir}/              # -w, with no -t: one run per workspace
├── logs/                # One log per step
├── status.json          # Machine-readable run status
├── params.json          # Parameters this run actually used
└── tmp/                 # Unique temporary directories (removed unless --keep-tmp)
```

With `-t`, each run gets its own subdirectory so several can share a workspace:

```
{work_dir}/
├── {task_id}/           # Same contents as above, per run
└── {other_task_id}/
```

A run claims its output directory for its duration, so a second run writing to the same place
fails immediately instead of interleaving outputs. The claim records which host and PID holds it,
so a collision says who — and a claim left behind by a killed run is reported as stale, with the
file to remove.

A pipeline may also declare a `cache_dir` under the workspace: one flat pool that steps marked
`cache = true` share across runs, keyed on their declared parameters, their script contents, and
their cached upstreams. Every step can read it through `$CACHE_DIR`; concurrent runs coordinate
through per-step deadline markers, so two runs starting cold produce one copy of the work. See
[Cached steps](docs/MANIFEST_REFERENCE.md#cached-steps).

## Pipeline Registry

Register pipelines for convenient name-based execution:

```bash
flowrs register ./my_pipeline --name mypipe
flowrs run mypipe -i /data -w ./work -t run001
flowrs list                      # View registered pipelines
flowrs unregister mypipe
```

Registry is stored at `~/.flowrs/registry.toml`.

A `.flowpkg` is **copied** into `~/.flowrs/packages/`, named by the digest of its bytes, so a
registered name keeps working after the original file moves and cannot silently change meaning
when a package is rebuilt at the same path. Identical bytes registered twice deduplicate to one
file, and `unregister` removes the stored copy only once no other name references it. A directory
is registered by reference instead — someone iterating on a pipeline needs the registry pointing
at their working tree, so `unregister` never touches it.

## License

FlowRs requires a valid license to run. Licenses are machine-bound and expire after a set period.

```bash
flowrs license status              # Check current license status
flowrs license add customer.license # Install a license file
flowrs license fingerprint         # Get machine fingerprint for license requests
```

License search paths (in order):
1. `./flowrs.license`
2. `./license.json`
3. `/etc/flowrs/license.json`
4. `~/.flowrs/license.json`

Contact your administrator to request a license. You'll need your machine fingerprint from `flowrs license fingerprint`.

## Support

- Issues and questions: [GitHub Issues](https://github.com/omegahh/flowrs/issues)
