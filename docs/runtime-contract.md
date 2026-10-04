## Runtime contract

The authoritative version ships with every pipeline as **`stdlib/CONTRACT.md`** — read that for
the full detail. This is the summary.

### Always present

| Variable       | Meaning                                                        |
| -------------- | -------------------------------------------------------------- |
| `INPUT_DIR`    | The run's input directory, as given to `-i`. **Read-only**     |
| `OUT_DIR`      | Where this step writes results. Created before the step starts |
| `TMP_DIR`      | Scratch space; kept on failure or signal, removed on success unless `--keep-tmp` |
| `LOG_DIR`      | Where the engine writes this step's log                        |
| `WORK_DIR`     | The run's working directory, as given to `-w`                  |
| `FLOWRS_UNIT`  | This unit's name — e.g. `align`, `detectors/probe_reads`, or `hooks/on_failure/notify` |
| `FLOWRS_UNIT_KIND` | What kind of unit is running: `step`, `hook`, or `detector` |
| `THREADS`      | Threads granted to a step or detector; hooks receive `1` without holding a permit |
| `FLOWRS_VERBOSITY` | The run's `-q`/`-v` level, `0`–`3` quietest-first          |

For a step or detector, `THREADS` is a grant, not a suggestion: the engine took that many permits
from the budget and will not hand them to anyone else. A step that spawns more oversubscribes the
machine for everything beside it. A hook receives `THREADS=1` as an expectation but holds no permit.

### Conditionally present

**Absent**, not empty, when they do not apply — so a step reading one under `set -u` fails loudly
instead of building a path with an empty segment.

| Variable           | Present when                                                                      |
| ------------------ | --------------------------------------------------------------------------------- |
| `TASKID`           | The run used `-t`. Write `${TASKID:-}` if your step is optional about it          |
| `CACHE_DIR`        | The pipeline declares `cache_dir`. One flat directory shared by every cached step |
| `ITEM_DIR`         | The step scatters and this execution is one of its items                          |
| `FLOWRS_COLLECTION` | The step scatters. The collection its items came from                            |
| `FLOWRS_ITEM_ID`   | The step scatters. This item's id, as the collection file spelled it              |
| `FLOWRS_ITEM_INDEX` | The step scatters. This item's position in the file, 0-based                     |
| `FLOWRS_ITEM_FILE` | The step scatters. A JSON file holding this item's metadata and every column      |
| `FLOWRS_GATHER_MANIFEST` | The step gathers. A JSON file listing every instance it is collecting       |

`FLOWRS_ERROR_MAP` is **always** set: compact JSON, `{"CODE":exit_code}`, holding your `[[errors]]`
and the built-in input-health codes together — so an empty map never means "nothing declared".

Every resolved parameter is exported as its **uppercased name**: `[params.min_quality]` arrives as
`$MIN_QUALITY`.

### Path setup

`PYTHONPATH` gets `stdlib/python`, plus `lib/python` when non-empty. `R_LIBS_USER` gets
`stdlib/r` and `lib/r` on the same rule. Both **prepend**, preserving any existing value. The
pipeline's `bin/` is prepended to `PATH`, so a vendored tool shadows one installed on the machine.

`BASH_ENV` names `stdlib/bash/flowrs.sh` and `R_PROFILE_USER` names `stdlib/r/flowrs.R`. Both make
that language's helpers implicit, and each is set only when the file exists, so a pipeline without
one gets no dangling variable.

### Working directory

**A unit runs in the directory you launched `flowrs` from**, not the pipeline root — the same for a
step, a detector, and a hook. A script writing a relative path lands it beside your shell prompt.
That is expected, and it is why the engine hands you `OUT_DIR` and `TMP_DIR`: build paths from
those rather than from the cwd, and a step behaves the same wherever it was launched.

### Path expansion

In `outputs`, `${VAR}` is expanded against the run's own variables. An unknown variable is left
literal rather than becoming empty, so a typo shows up as a path containing `${NOPE}` instead of
a file quietly written to the wrong place. `${TASKID}` stays literal when the run had no `-t`.

### Logs

Each scalar step gets `logs/<step>.log`, and each scattered item gets `logs/<step>/<item>.log`,
capturing both stdout and stderr. Detectors use `logs/detectors/<script>.log`; hooks use
`logs/hooks/<phase>/<script>.log`. Stdlib lines are tagged
`[FLOWRS:LEVEL]`; anything else your script prints lands there verbatim.

**The log file is complete; the console is filtered.** Every tagged line reaches the file whatever
verbosity the run used, and `-q`/`-v` only decide which also reach the terminal:
`INFO`/`WARN`/`ERROR` by default, `log_debug` at `-v`, `log_trace` at `-vv`. So a run that finished
badly still has its `DEBUG` detail on disk. Hooks and detectors log the same way, under the paths in
[Read the output in the getting-started guide](getting-started.md#read-the-output).

The two streams are drained concurrently, so **their relative order in the file is not guaranteed**.
If ordering matters for a diagnostic, write both through the stdlib log helpers, which go to one
stream.
