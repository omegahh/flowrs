# FlowRs

**Fast, safe workflow orchestration for data analysis pipelines**

FlowRs is a standalone pipeline lifecycle manager that executes DAG-based workflows defined in TOML manifests. It features parallel step execution, cooperative signal handling, typed parameter resolution with category-aware defaults, and a bundled standard library for bash, Python, R, and C++ scripts.

## Features

- ✅ **DAG-based execution** — automatic parallelization of independent steps
- ✅ **Type-safe parameters** — integer, number, string, boolean with `min`/`max`/`enum` validation
- ✅ **Category-aware defaults** — pipeline-defined discriminator selects per-category param defaults
- ✅ **Cross-parameter constraints** — `when`/`require` expressions validated after resolution
- ✅ **Trigger rules** — Airflow-style `all_success` / `one_failed` / `always` / etc.
- ✅ **Error taxonomy** — structured error codes with retry policies and per-error hooks
- ✅ **Lifecycle hooks** — on_start, on_success, on_failure, and per-error-code hooks
- ✅ **Multi-language stdlib** — bash, Python, R, and C++ (header-only)
- ✅ **Signal handling** — graceful cancellation with process-group cleanup
- ✅ **Scaffold system** — `flowrs create` bundles a stdlib into each pipeline
- ✅ **License system** — RSA-2048 signatures with NTP-backed clock-tamper detection
- ✅ **Registry** — name-based pipeline lookup at `~/.flowrs/registry.toml`
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

## Quick Start

```bash
# Create a new pipeline
flowrs create my_pipeline

# Inspect it
flowrs show ./my_pipeline

# Run it
flowrs run ./my_pipeline -i /path/to/input -t task001

# Dry run (show execution plan without running)
flowrs run ./my_pipeline -i /path/to/input -t task001 -m dry-run
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
├── bin/                 # Helper tools, e.g. discriminator detectors
└── tests/               # Test fixtures
```

### Manifest Example

```toml
[pipeline]
name = "my_pipeline"
version = "1.0"
min_threads = 4   # optional: refuse to run with fewer

# Pipeline-defined discriminator drives category-specific param defaults
[pipeline.discriminator]
param = "SEQTYPE"
detector = "detect_seqtype.sh"   # script in bin/

[pipeline.discriminator.categories]
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

# Category-specific defaults
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
source "${PIPELINE_DIR}/stdlib/bash/flowrs.sh"

log_info "Starting QC step"

threads=$(get_config_int "THREADS" "8")
min_quality=$(get_config_int "MIN_QUALITY" "20")

require_file "${RAW_DIR}/sample.fastq.gz" "Input FASTQ"
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
    flowrs::require_file(ctx.raw_dir / "sample.fastq.gz", "Input FASTQ");

    log.info("QC completed");
    return 0;
}
```
Compile flags: `-std=c++17 -Istdlib/cpp -Istdlib/cpp/vendor -lz`. Vendored headers: `clipp.h` (arg parsing) and `kseqpp/` (FASTA/FASTQ reading).

## CLI Reference

```bash
# Pipeline execution
flowrs run <PIPELINE> -i DIR -t TASK [OPTIONS]
    -i, --input <DIR>            Input directory
    -t, --task <ID>              Task ID (3-64 chars, [A-Za-z0-9_-])
    -o, --output <DIR>           Optional separate output dir (input becomes read-only raw data)
    -c, --config <FILE>          Config file: JSON, TOML, or KEY=VALUE (.env style); detected by extension
    -p, --param <KEY=VALUE>      Inline param override; repeatable
    -@, --threads <N>            Threads available for execution (default: CPU count)
    -s, --start-step <STEP>      Start from a specific step
    -e, --end-step <STEP>        End at a specific step
    -k, --skip-steps <STEP>...   Skip specific steps
    -m, --mode <MODE>            production | debug | dry-run [default: production]
    -v, --verbose                Verbose output (implied by --mode debug)

# Pipeline management
flowrs create <NAME> [-d DESC] [--update]
                                  Scaffold a new pipeline (or update its bundled stdlib)
flowrs compile <DIR> [--check] [-o OUT] [--sign KEY]
                                  Validate a manifest. (Packaging into .flowpkg and signing
                                  are accepted on the CLI but not yet implemented.)
flowrs show <PIPELINE>            Display pipeline details and DAG
flowrs register <PATH> [--name N] Register a pipeline for name-based lookup
flowrs unregister <NAME>          Remove a registered pipeline
flowrs list [--detailed]          List registered pipelines

# License management
flowrs license status [-f FILE]   Show license status with cryptographic validation
flowrs license add <FILE>         Install a license file to ~/.flowrs/license.json
flowrs license fingerprint        Show machine fingerprint for license requests
```

## Standard Library

Each scaffold bundles a stdlib copied into the pipeline directory:

**Bash (`stdlib/bash/flowrs.sh`):**
- Logging: `log_info`, `log_warn`, `log_error`, `log_success`, `log_debug`, `die`
- Validation: `require_file`, `require_dir`, `require_var`, `require_command`
- Config: `get_config`, `get_config_int`, `get_config_bool`
- Execution: `exec_cmd`, `exec_cmd_silent`, `exec_with_retry`
- File utils: `get_fastq_prefix`, `list_r1_files`, `count_reads`
- Time: `timestr`, `elapsed_time`, `benchmark`
- Locking: `acquire_lock`, `release_lock`, `with_lock`

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
- Time utilities

**C++ (`stdlib/cpp/flowrs.hpp`, header-only):**
- `flowrs::Context::from_env()` — runtime context (mirrors Python)
- `flowrs::Logger` — RAII logger
- `flowrs::get_config<T>()`, `flowrs::require_file/dir/command()`
- File and time utilities matching the bash/python/R interface

## Error Taxonomy & Retry Logic

FlowRs supports structured error reporting with automatic retry policies and per-error hooks.

### Defining Error Codes

```toml
[[errors]]
code = "NO_INPUT_DATA"
description = "Required input files not found"
retryable = false

[[errors]]
code = "NETWORK_TIMEOUT"
description = "Remote resource unreachable"
retryable = true
max_retries = 3
```

### Emitting Structured Errors

**Bash:**
```bash
flowrs_error NO_INPUT_DATA "No FASTQ files found" \
    input_dir="$INPUT_DIR" \
    expected_pattern="*.fq.gz"
```

**Python:**
```python
from flowrs import flowrs_error
flowrs_error("NETWORK_TIMEOUT", "API request failed", 
    endpoint="https://api.example.com", 
    status_code="504")
```

**R:**
```r
flowrs_error("LOW_COVERAGE", "Coverage below threshold",
    taxid = "562", coverage = "3.2", threshold = "10.0")
```

Errors are captured in `status.json` with full context and trigger retry logic based on manifest definitions.

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
- `on_error`: `ERROR_CODE`, plus all context fields from the error (sensitive keys filtered)

All hooks run to completion even if one fails, ensuring cleanup and notifications always execute.

## Execution Model

1. Parse and validate `manifest.toml`.
2. Resolve parameters: `const` > user override (`-p`/`-c`) > category-specific default > base default.
3. If a discriminator is declared, run its detector to select the active category.
4. Build DAG from step dependencies; check for cycles.
5. Decompose into parallel execution layers (Kahn-style topological levels).
6. Execute layers; steps within each layer run concurrently.
7. On failure or signal (SIGINT/SIGTERM), evaluate trigger rules to decide whether downstream steps still run; cancel and kill remaining process trees on shutdown.
8. Write `status.json` and `config.json` to the output directory.

## Workspace Layout

Without `-o`, `input_dir` doubles as the workspace root and outputs are created inside it. With `-o output_dir`, `input_dir` is treated as read-only raw data and all outputs go under `output_dir`. The output structure is:

```
{workspace}/
├── out_{TASKID}/        # persisted results, log/, status.json, config.json
└── tmp_{TASKID}/        # cleaned up unless --mode debug
```

Steps see `WORKSPACE_DIR` (the workspace root) for cross-task coordination such as locks.

## Pipeline Registry

Pipelines can be registered for name-based lookup:

```bash
flowrs register ./my_pipeline --name mypipe
flowrs run mypipe -i /data -t run001
flowrs unregister mypipe
```

Registry is stored at `~/.flowrs/registry.toml`.

## License

FlowRs uses RSA-2048 digital signatures for license enforcement with clock-tamper resistance.

```bash
flowrs license status            # show current license
flowrs license add customer.license   # install to ~/.flowrs/license.json
flowrs license fingerprint       # machine fingerprint for license requests
```

**Clock-tamper resistance:**
- Queries NTP servers for authoritative time when reachable
- Caches the NTP offset for 24 h so repeated runs don't re-query
- Maintains a monotonic last-seen timestamp at `~/.flowrs/.last_seen` to detect rollback
- 60-second drift tolerance avoids false positives

License search paths (in order):
1. `./flowrs.license`
2. `./license.json`
3. `/etc/flowrs/license.json`
4. `~/.flowrs/license.json`

A valid license is required to run FlowRs. Contact your administrator to request one; use `flowrs license fingerprint` to obtain the machine fingerprint needed for the request.

## Support

- Issues and questions: [GitHub Issues](https://github.com/omegahh/flowrs/issues)
