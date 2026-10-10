# Script environment

Steps, detectors, and hooks receive paths and logging helpers from FlowRs. The detailed helper
reference ships in a scaffold as `stdlib/CONTRACT.md`.

## Unit variables

| Variable | Meaning |
| --- | --- |
| `INPUT_DIR` | Input directory; scripts must not modify it |
| `OUT_DIR` | Run output directory, including the task id when supplied |
| `WORK_DIR` | Work directory passed with `-w` |
| `TMP_DIR` | Scratch; cleanup is attempted on handled exit unless `--keep-tmp` was supplied |
| `LOG_DIR` | Run log directory |
| `FLOWRS_UNIT` | Unit name, such as `align`, `detectors/probe`, or `hooks/on_failure/notify` |
| `FLOWRS_UNIT_KIND` | `step`, `detector`, or `hook` |
| `THREADS` | Thread allocation for this execution; hooks receive `1` |
| `FLOWRS_VERBOSITY` | Console verbosity, `0` to `3` |
| `FLOWRS_ERROR_MAP` | JSON mapping declared and built-in error names to exit codes |

Resolved parameters are exported under uppercase names: `[params.min_quality]` becomes
`MIN_QUALITY`. Detectors and `on_start` run before resolution and do not receive those values.
Do not put secrets in parameters; resolved values are saved in `params.json`.

Pass `THREADS` to tools that support a thread option. Native pools such as OpenMP, BLAS,
NumExpr, Rayon, and Polars receive limits matching this value at startup. Multiple worker
processes must divide the allocation among themselves.

## Conditionally present

These engine variables are absent when they do not apply.

| Variable | Present when |
| --- | --- |
| `TASKID` | `-t` was supplied |
| `CACHE_DIR` | The pipeline declares `cache_dir` |
| `ITEM_DIR` | This is an item execution of a scattered step |
| `FLOWRS_COLLECTION` | This step scatters; identifies the collection |
| `FLOWRS_ITEM_ID` | This step scatters; holds the original item id |
| `FLOWRS_ITEM_INDEX` | This step scatters; holds its zero-based collection position |
| `FLOWRS_ITEM_FILE` | This step scatters; points to JSON item metadata |
| `FLOWRS_GATHER_MANIFEST` | This step gathers; points to the list of gathered instances |

Use `${TASKID:-}` in Bash when the task id is optional. Read item data from
`FLOWRS_ITEM_FILE`; build output paths from `ITEM_DIR` rather than the item id.

## Paths and language setup

Scripts run in the directory from which `flowrs` was launched. Use the supplied directories
instead of relative paths for data and outputs.

Manifest `outputs` accept a leading `${OUT_DIR}`, `${WORK_DIR}`, or `${TMP_DIR}`, or an absolute
path. `${CACHE_DIR}` requires a cached scalar step; scattered outputs require `${ITEM_DIR}`.
Unknown variables, additional variables, and `.` or `..` components are rejected.
See the [step reference](manifest-reference.md#stepsname--the-unit-of-work).

The pipeline's `bin/` precedes the existing `PATH`. Python's module path includes
`stdlib/python/` and non-empty `lib/python/`; R's library path includes the corresponding
R directories. Existing search paths are preserved.

Bash loads the shipped helpers through `BASH_ENV` when the file exists. R startup loads them
through `R_PROFILE_USER` when present, unless startup options disable it. Python scripts import
`flowrs`; C++ steps include `flowrs.hpp` at build time. See [Stdlib](stdlib.md).

## Logs

Scalar step logs are `logs/<step>.log`; scattered logs are `logs/<step>/<item-key>.log`.
Detectors use `logs/detectors/<script-stem>.log`, and hooks use
`logs/hooks/<phase>/<script-stem>.log`; script extensions are omitted from these names.

Logs capture stdout and stderr, including stdlib debug and trace messages that console verbosity
hides. Use `-v` for debug or `-vv` for trace on the console. Stdout and stderr can interleave;
use one stream when diagnostic order matters.

See [Read the result](getting-started.md#read-the-result) for the run files.
