# Running FlowRs

## Contents

- Commands
- Create, compile, and inspect
- Run options
- Package access and slices
- Resume, threads, scatter, and cache
- Signals, scratch, packaging, and registry

## Commands

Use the command that matches the operation:

| Command | Operation |
| --- | --- |
| `flowrs create NAME` | Create a scaffold |
| `flowrs create NAME --update` | Replace binary-owned scaffold files |
| `flowrs compile DIR` | Clean and rebuild with Makefile when present, then validate |
| `flowrs compile DIR -o FILE.flowpkg` | Validate and create a packaged pipeline (plaintext `.flowpkg`) |
| `flowrs inspect PIPELINE` | Show the manifest projection |
| `flowrs inspect PIPELINE --check-environment` | Check declared host tools and libraries |
| `flowrs registry add PATH [--name NAME]` | Register a directory or package |
| `flowrs registry list [--detailed] [--json]` | List registered pipelines |
| `flowrs registry remove NAME` | Remove a registration |
| `flowrs run PIPELINE ...` | Execute a pipeline |

PIPELINE accepts a registered name, a directory, or a .flowpkg path. compile --json emits a
diagnostic envelope on stdout for success and failure. inspect --json emits its projection on
success and an envelope only on failure. Every source shares top-level manifest fields such as
name, version, steps, and parameters; type and source identify its state and location. Protected
sources add authorization. If access fails, the envelope includes inspection with the readable
metadata; unopened manifest fields are omitted. run has no --json; use status.json.
Argument-parser errors exit 64 with usage on stderr and no JSON; check stdout before parsing.

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
~~~

Compile validates the source tree and writes no package. Missing step or detector executables are fatal.
A Makefile must provide a clean target that removes its compiled outputs. When a Makefile exists, compile runs
make clean, then make before validation, rebuilding even after header-only changes. Either command
failing stops compilation. Missing hooks produce warnings. A supplied `.flowpkg` may require access
configured by its publisher. If FlowRs cannot open a package, report the exact error and package
version to the publisher. Step executables must be at the paths declared by the manifest, relative
to steps/. Files shared across steps can be placed in lib/, bin/, hooks/, or stdlib/.

Inspect shows basic identity and source metadata first, then Authorization for a protected package,
then Pipeline settings, steps, parameters, constraints, errors, and hooks. Authorization includes
server/customer names, machine permission, grant scope, available run capacity when limited, and
access expiry with time remaining. A full run quota still permits inspection. A refusal preserves
the basic metadata and ends with the error on stderr; send the publisher that error and version.
Use -v for technical IDs and fingerprints. Source paths refer to the supplied pipeline, not its
temporary extraction directory.

For ELF checks, install `readelf` (binutils) and put `ldconfig` on PATH. Inspection reads dependency
metadata without executing pipeline binaries. It checks direct and transitive library presence,
not symbol or version compatibility. `$ORIGIN` expands; `$LIB` and `$PLATFORM` do not, so paths
using those tokens can produce missing-library reports.

| Command | Additional flags |
| --- | --- |
| `create` | `-d, --description TEXT`; `--update` |
| `compile` | `--json` |
| `inspect` | `--check-environment`; `--json` |
| `registry add` | `--name NAME` |
| `registry list` | `-d, --detailed`; `--json` |

Use `-h, --help` on each command and `flowrs -V, --version` for the installed version.

## Run

~~~text
flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR [options]
~~~

Required flags:

| Flag | Rule |
| --- | --- |
| `-i, --input-dir DIR` | Existing input directory with read and search (execute) permission |
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
| `--keep-tmp` | Retain scratch after success, failure, or handled cancellation |

Output flags are global:

| Flag | Rule |
| --- | --- |
| `-q, --quiet` | Show errors, failures, and cancellation only |
| `-v, --verbose` | Add debug lines; repeat as -vv for trace |

-q wins over -v. A run claims its output directory for the duration; do not run two processes
against one task directory.

## Package Access

A supplied `.flowpkg` may need access configured by its publisher. If FlowRs reports an access
failure or cannot open a package group, do not change the artifact or invent credentials. Send the
publisher the exact error, package version, and exit code.

Exit 79 or a message that no access is available means the current runner cannot use that package.
If a message says a group could not be opened or decrypted, the access material did not authenticate
that group, or the package may be incomplete. Pipeline edits cannot fix either cause; report the
exact error and package version to the publisher.

When protected-release setup fails before steps start, exit 64 means local access configuration is
missing or invalid; check `FLOWRS_RELEASE_SERVER`, `FLOWRS_RELEASE_CA`, and `FLOWRS_IDENTITY`.
Exit 70 indicates a server, endpoint, or server-response problem. Give the server operator the
exact error and correlation ID when one is present.

## Slices

-s and -e produce a fresh subgraph. -k skips named steps while preserving graph edges. Reject an
undeclared step name. --resume cannot be combined with any of these three flags. Teardown steps
are not removed by a slice and are scheduled after the selected main graph.
When -s selects a gather step, its scattered producers are manifest inputs only: their per-item
outputs must already exist in the same task directory, and they are not rerun.

## Resume

Resume the same pipeline name in the same task directory:

~~~bash
flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR -t RUN_ID --resume
~~~

### What Resume Compares

FlowRs records a fingerprint of the complete `-i` tree and compares it with the current tree
when resuming. A difference refuses the resume unless `--force` is supplied.

Keep `-w` outside `-i`. If the work directory is inside the input directory, the run's own
outputs, logs, and `status.json` become part of the input tree. By default, scratch is under the
output directory too. These files change as the run proceeds, so a later `--resume` sees a
different input fingerprint. If `--tmp-dir` is set, keep that path outside `-i` as well.

Resume applies to the same pipeline name and the same output directory selected by `-w` and `-t`.
It also refuses a changed collection identity or profile selector. Use a new work directory or
task ID to start anything else.

Resume replays the prior planned step set and retains completed uncached steps. Cached steps
reenter cache handling, and teardown steps run again. It
loads the prior status.json.params as a baseline, while new -p and -c values override it. Readonly
parameters resolve from the current manifest's defaults, including profile overrides, instead of
the baseline. Explicit -p and -c overrides of readonly parameters are refused.

The accepted parameters and execution state are written together in status.json after resume
validation. A refused resume preserves the prior parameters and step results. A record without
params has no accepted parameter set; run without --resume to start fresh.

The manifest's pipeline.name must match the recorded run. A different name is refused even with
--force or changed versions; use the original pipeline or start a fresh task.

The engine compares engine version, pipeline version, and the input fingerprint,
and collection digests for scattered steps. A changed version starts the pipeline from scratch in
the existing directory. With versions unchanged, a profile-selector override that changes its
value is refused even with --force; remove the override or rerun from scratch. A changed input
is refused unless `--force` is supplied. A changed collection identity is refused even with
--force; use a fresh task or restore the parsed collection.
A cache-key parameter override is refused when its producer or a descendant has retained completed
results. --force bypasses this refusal and the input refusal; it does not recompute retained steps.
Use a fresh task to avoid mixing old and new results.

Script edits are outside the version fingerprint. Bump pipeline.version or use a fresh task after
behavior changes. For edits outside cache tracking, also change or clear the cache directory.

## Threads And Scatter

-@ is a permit budget, not a process count. A fixed threads = N execution costs N permits,
reduced to the run budget if N exceeds it. Ready threads = "auto" steps divide the available
share by threads_weight. Pass the supplied THREADS allocation to tools rather than assuming
the declared count.

--max-in-flight counts items of one logical scattered step. It is a queue bound and does not
replace the thread budget. Effective concurrency is bounded by both. Items launch in collection
file order. A scattered output belongs below ${ITEM_DIR}. A gather waits for the named scattered batches and
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
values, the declared output scope and paths, parsed collection identity, and upstream execution
identities, including uncached intermediate executables and their declared cache-key parameters.
Pipeline and step names and versions are not hashed; differently named steps share an entry when
their contracts match. Declare cached outputs in outputs; hits check their existence, not content
integrity.
Input stat tracking uses relative paths, sizes, mtimes, directory names, and regular-file symlink
spelling/resolved metadata, ignoring common OS metadata files. Same-size, same-mtime edits can escape it.
Imported libraries, external tools, thread counts, other environment values, and unlisted parameters
are outside tracking. The engine assumes outputs depend only on the executable, declared parameters,
inputs, and upstream identities. Keep other influences out of cached output or manage invalidation
yourself. Use a new cache directory or remove affected entries after these change; a new task id
alone is insufficient.

A cache hit is cached, not skipped. Writers may replace an entry while another run uses it.
Consumed publications are checked before and after each executing step, including teardown.
Replacement fails the affected run with CACHE_INPUT_CHANGED (121), even if the original cache
key is restored, and affected consumers do not publish derived cache entries. Resolve the conflict
and rerun. Checks do not lock readers or undo a step's external side effects.

Scattered cache hits copy declared outputs into the task's item directory and recheck the
publication after copying. A replacement during restoration fails the item with
CACHE_INPUT_CHANGED (121) and removes its incomplete restored outputs, preserving other steps'
files. Siblings finish normally. This also applies to restoration for skipped or resumed steps.

## Signals And Scratch

SIGINT, SIGTERM, SIGHUP, and SIGQUIT cancel a run and normally return 128 + signal_number. Running
processes are killed as a group. Cancellation during scheduling skips unstarted steps with reason
cancelled; earlier cancellation can leave them pending. Teardown steps do not start after
cancellation. on_failure runs once the hook lifecycle has started; on_error does not run for cancellation.
Error-hook batches admitted before cancellation still run, one batch at a time, with a timeout per
script once it starts. Repeated failures of the same code do not enqueue more batches.
A second signal exits at once without waiting for hooks or a final status.json.
Cache I/O has a five-minute idle limit, reset by copy progress. On cancellation or timeout, a
worker gets five seconds to stop; if it remains stuck, FlowRs terminates with claims and scratch
retained and status.json may be incomplete. A second signal also retains them while cache I/O is
active. Restore filesystem access and verify the previous processes have exited before using
--resume to recover the stale run claim. Kernel I/O waits can delay process termination.
SIGKILL, power loss, and machine reset cannot be handled.

FlowRs attempts to remove scratch on success, failure, and handled cancellation unless --keep-tmp
was supplied on that invocation. Cleanup errors can leave residue. Use the flag before reproducing
a failure; the retained path is printed.

## Packaging And Registry

~~~bash
flowrs registry add ./demo.flowpkg --name demo
flowrs registry remove demo
~~~

Package registration copies .flowpkg files into content-addressed storage. Directory registration
keeps a path reference. Use a registry name with run or inspect. Compile accepts a pipeline directory.

Read the registry `Type` column or JSON `type` field as follows:

| State | Source |
| --- | --- |
| `plaintext` | A pipeline directory |
| `packaged` | A plaintext `.flowpkg` file |
| `protected` | A publisher-provided `.flowpkg` release requiring authorization |
