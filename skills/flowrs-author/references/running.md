# Running FlowRs

## Commands

Use the command that matches the operation:

| Command | Operation |
| --- | --- |
| `flowrs create NAME` | Create a scaffold |
| `flowrs create NAME --update` | Replace binary-owned scaffold files |
| `flowrs compile DIR` | Clean and rebuild with Makefile when present, then validate; write no package |
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
Argument-parser errors can exit 2 with usage on stderr and no JSON; check stdout before parsing.

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
A Makefile must provide a clean target that removes its compiled outputs. When a Makefile exists, compile runs
make clean, then make before validation, rebuilding even after header-only changes. Either command
failing stops compilation and packaging. Missing executables without -o produce warnings; check
that referenced files exist before running. Running a plain package
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
| `-i, --input-dir DIR` | Existing input directory; scripts must treat it as read-only |
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

## Licence Gates

Install a licence before running a protected package:

~~~bash
flowrs license fingerprint
flowrs license add LICENSE_FILE
flowrs license status
~~~

The search order is ./flowrs.license, ./license.json, /etc/flowrs/license.json, and
~/.flowrs/license.json. Protected packages need a valid licence plus
pipeline_grants[PIPELINE_NAME] matching their source digest. A non-empty machine list must include
this machine; an empty list permits any machine. Plaintext directories and packages do not consult
a licence.

## Slices

-s and -e produce a fresh subgraph. -k skips named steps while preserving graph edges. Reject an
undeclared step name. --resume cannot be combined with any of these three flags. Teardown steps
are not removed by a slice and are scheduled after the selected main graph.

## Resume

Resume in the same task directory:

~~~bash
flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR -t RUN_ID --resume
~~~

Resume replays the prior planned step set and retains completed uncached steps. Cached steps
reenter cache handling, and teardown steps run again. It
loads the prior params.json as a baseline, while new -p and -c values override it. Readonly
parameters resolve from the current manifest's defaults, including profile overrides, instead of
the baseline. Explicit -p and -c overrides of readonly parameters are refused.

The engine compares engine version, pipeline version, input fingerprint when caching is enabled,
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
values, parsed collection identity, and relevant upstream identities, including uncached intermediate
executables. Declare cached outputs in outputs; hits check their existence, not content integrity.
Input stat tracking uses relative paths, sizes, mtimes, directory names, and regular-file symlink
spelling/resolved metadata, ignoring common OS metadata files. Same-size, same-mtime edits can escape it.
Imported libraries, external tools, and unlisted parameters are outside tracking. Use a new cache
directory or remove affected entries after these change; a new task id alone is insufficient.

A cache hit is cached, not skipped. Avoid conflicting writers to shared output paths. Cache
replacement detected at step boundaries fails with CACHE_INPUT_CHANGED (121); resolve the conflict
and rerun. The check does not protect a process's reads during execution.

## Signals And Scratch

SIGINT, SIGTERM, SIGHUP, and SIGQUIT cancel a run and normally return 128 + signal_number. Running
processes are killed as a group. Cancellation during scheduling skips unstarted steps with reason
cancelled; earlier cancellation can leave them pending. Teardown steps do not start after
cancellation. on_failure runs once the hook lifecycle has started; on_error does not run for cancellation.
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
