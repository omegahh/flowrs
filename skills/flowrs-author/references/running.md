# Running FlowRs

## Commands

Use the command that matches the operation:

| Command | Operation |
| --- | --- |
| `flowrs create NAME` | Create a scaffold |
| `flowrs create NAME --update` | Replace binary-owned scaffold files |
| `flowrs compile DIR` | Run Makefile when present and validate; write no package |
| `flowrs compile DIR -o FILE` | Validate and write a plain .flowpkg |
| `flowrs compile DIR -o FILE --encrypt` | Validate and write a protected .flowpkg |
| `flowrs inspect PIPELINE` | Show the manifest projection |
| `flowrs inspect PIPELINE --check-environment` | Check declared host tools and libraries |
| `flowrs license fingerprint` | Print the machine fingerprint |
| `flowrs license add FILE` | Validate and install a licence |
| `flowrs license status` | Validate the licence found on the search path |
| `flowrs license status --file FILE` | Validate one licence file |
| `flowrs registry add PATH [--name NAME]` | Register a directory or package |
| `flowrs registry list [--detailed] [--json]` | List registered pipelines |
| `flowrs registry remove NAME` | Remove a registration |
| `flowrs run PIPELINE ...` | Execute a pipeline |

PIPELINE accepts a registered name, a directory, or a .flowpkg path. compile --json emits a
diagnostic envelope on stdout for success and failure. inspect --json emits its projection on
success and an envelope only on failure. run has no --json; use status.json.

## Create

~~~bash
flowrs create demo -d "Example pipeline"
cd demo
flowrs create . --update
~~~

The scaffold owns the standard library and language configuration. --update preserves the
manifest, steps, sources, and build files. Add executables under steps/, detectors under bin/, and
hooks under hooks/.

## Compile And Inspect

~~~bash
flowrs compile ./demo --json
flowrs inspect ./demo
flowrs inspect ./demo --json
flowrs inspect ./demo --check-environment
flowrs compile ./demo -o demo.flowpkg
flowrs compile ./demo -o demo-protected.flowpkg --encrypt
~~~

Without -o, compile writes no package. With -o, missing step or detector executables are fatal.
A Makefile runs before validation and may write build outputs. Missing executables without -o
produce warnings; check that every referenced file exists before running. Running a plain package
needs no licence; running a protected package needs a valid licence and matching pipeline grant.

For ELF checks, install `readelf` (binutils) and put `ldconfig` on PATH. Inspection reads dependency
metadata without executing pipeline binaries. It checks direct and transitive library presence,
not symbol or version compatibility. `$ORIGIN` expands; `$LIB` and `$PLATFORM` do not, so paths
using those tokens can produce missing-library reports.

| Command | Additional flags |
| --- | --- |
| `create` | `-d, --description TEXT`; `--update` |
| `compile` | `-o, --output FILE`; `--encrypt`; `--sign-with FILE` (RSA private PEM); `--author NAME`; `--json` |
| `inspect` | `--check-environment`; `--json` |
| `registry add` | `--name NAME` |
| `registry list` | `-d, --detailed`; `--json` |
| `license status` | `--file FILE` |

`--encrypt`, `--sign-with`, and `--author` require `-o`. Use `-h, --help` on each command
and `flowrs -V, --version` for the installed version.

## Run

~~~text
flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR [options]
~~~

Required flags:

| Flag | Rule |
| --- | --- |
| `-i, --input-dir DIR` | Existing read-only input directory |
| `-w, --work-dir DIR` | Work directory; created after validation when absent |

Identity and parameters:

| Flag | Rule |
| --- | --- |
| `-t, --task-id ID` | Optional 3-64 character [A-Za-z0-9_-] id; output is WORK_DIR/ID/ |
| `-p, --param KEY=VALUE` | Repeatable override; overrides config |
| `-c, --config FILE` | JSON, TOML, or KEY=VALUE file |

Execution:

| Flag | Rule |
| --- | --- |
| `-@, --threads N` | Whole thread budget; default is pipeline minimum or CPU count |
| `--max-in-flight N` | Non-zero cap on concurrent items of one scattered step |
| `-s, --start-step STEP` | Keep the chosen step and downstream steps |
| `-e, --end-step STEP` | Keep the chosen step and upstream steps |
| `-k, --skip-steps STEP...` | Mark named steps skipped and keep the rest |
| `--resume` | Continue the prior plan in the same output directory |
| `--force` | Requires --resume; bypass changed-input and completed-step cache-key drift refusals |
| `--tmp-dir PATH` | Absolute scratch base instead of OUT_DIR/tmp |
| `--keep-tmp` | Keep scratch after a clean run; failures and signals already keep it |

Output flags are global:

| Flag | Rule |
| --- | --- |
| `-q, --quiet` | Show errors, failures, and cancellation only |
| `-v, --verbose` | Add debug lines; repeat as -vv for trace |

-q wins over -v. A run claims its output directory for the duration; do not run two processes
against one task directory.

## Licence Gates

Install a licence before running a protected package:

~~~bash
flowrs license fingerprint
flowrs license add LICENSE_FILE
flowrs license status
~~~

The search order is ./flowrs.license, ./license.json, /etc/flowrs/license.json, and
~/.flowrs/license.json. Protected packages need a valid licence plus
pipeline_grants[PIPELINE_NAME] matching their source digest. Plaintext directories and packages
do not consult a licence.

## Slices

-s and -e produce a fresh subgraph. -k skips named steps while preserving graph edges. Reject an
undeclared step name. --resume cannot be combined with any of these three flags. Teardown steps
are not removed by a slice and are scheduled after the selected main graph.

## Resume

Resume in the same task directory:

~~~bash
flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR -t RUN_ID --resume
~~~

Resume replays the prior planned step set and treats completed and cached steps as satisfied. It
loads the prior params.json as a baseline, while new -p and -c values override it. Readonly
parameters resolve from the current manifest's defaults, including profile overrides, instead of
the baseline. Explicit -p and -c overrides of readonly parameters are refused.

The engine compares engine version, pipeline version, input fingerprint when caching is enabled,
and collection digests for scattered steps. A changed version starts the pipeline from scratch in
the existing directory. A changed input is refused unless `--force` is supplied; a changed
collection is always refused and requires a new run or restoration of the collection file. Editing
a step script is not part of the version fingerprint; bump the pipeline version or rely on the cache
identity.

## Threads And Scatter

-@ is a permit budget, not a process count. A fixed threads = N step costs N permits. Ready
threads = "auto" steps divide the available share by threads_weight. THREADS in a unit is its
allocation.

--max-in-flight counts items of one logical scattered step. It is a queue bound and does not
replace the thread budget. Effective concurrency is bounded by both. Items launch in collection
file order. A scattered output belongs below ${ITEM_DIR}. A gather waits for every instance and
reads ${FLOWRS_GATHER_MANIFEST}.

## Cache

~~~toml
[pipeline]
cache_dir = "shared"

[steps.align]
cache = true
cache_key = ["reference", "quality"]
outputs = ["${CACHE_DIR}/aligned.bam"]
~~~

The cache identity includes the executable bytes, input-tree stat fingerprint, declared cache-key
values, collection identity, and cached upstream identities. Declare every file written below
${CACHE_DIR}. A cache hit is cached, not skipped, because outputs exist. Do not share one cache
directory between runs that use incompatible cache keys.

## Signals And Scratch

SIGINT, SIGTERM, SIGHUP, and SIGQUIT cancel a run and normally return 128 + signal_number. Running
processes are killed as a group. Unstarted steps are skipped with reason cancelled. Teardown steps
do not start after cancellation. on_failure still runs; on_error does not run for cancellation.
SIGKILL, power loss, and machine reset cannot be handled.

Scratch survives failure and signals. A clean run removes it unless --keep-tmp is supplied.

## Packaging And Registry

~~~bash
flowrs registry add ./demo.flowpkg --name demo
flowrs registry remove demo
~~~

Package registration copies .flowpkg files into content-addressed storage. Directory registration
keeps a path reference. A registry name can be supplied anywhere a pipeline argument is accepted.
