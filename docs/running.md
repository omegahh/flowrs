## Running

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>] [options]
```

`<PIPELINE>` is a registered name, a directory, or a `.flowpkg`.

| Flag               | Effect                                                           |
| ------------------ | ---------------------------------------------------------------- |
| `-i, --input-dir`  | Input data. Read-only: the engine never writes here              |
| `-w, --work-dir`   | Work directory; created after the licence gate when absent       |
| `-t, --task-id`    | Outputs go to `WORK_DIR/TASKID/`. Omit for `WORK_DIR/` directly  |
| `-p, --param`      | `KEY=VALUE`, repeatable                                          |
| `-c, --config`     | Config file: JSON, TOML, or `KEY=VALUE` lines                    |
| `-@, --threads`    | The run's whole thread budget                                    |
| `--max-in-flight`  | Cap how many items of one scattered step run at once             |
| `-s, --start-step` | Start here, dropping everything upstream                         |
| `-e, --end-step`   | Stop here, dropping everything downstream                        |
| `-k, --skip-steps` | Skip named steps, keeping the rest                               |
| `--resume`         | Continue a prior run, skipping what completed                    |
| `--force`          | Permit a `--resume` override that a completed `cache_key` covers |
| `--tmp-dir`        | Base for scratch. `/dev/shm` for tmpfs, or any absolute path     |
| `--keep-tmp`       | Keep scratch after a clean exit                                  |
| `-q` / `-v` / `-vv` | Quieter / add `DEBUG` lines / add `TRACE` lines too             |

### Slices

`-s` keeps a step and everything downstream; `-e` keeps a step and everything upstream. Dangling
`depends_on` entries pointing at dropped steps are pruned, so the sub-DAG is valid on its own.

```console
$ flowrs run full -i input -w work6 -t slice -s analyze
     info Pipeline 'full': 4 main steps in 3 layers, 0 teardown steps
  success Pipeline completed: 4 steps completed, 0 skipped in 1s
```

`-k` skips named steps and keeps the rest of the graph:

```console
$ flowrs run full -i input -w work7 -t skip -k failer
  skipped 26/08/24 13:16:44 [failer] user
  success Pipeline completed: 6 steps completed, 1 skipped in 1s
```

All three flags refuse a step name the pipeline does not declare — which matters most for `-k`,
where a silent typo would run the step you meant to skip.

Combine them for a window out of the middle. What survives is the intersection — steps both
downstream of `-s` and upstream of `-e`:

```console
$ flowrs run chain -i in -w work -t slice1 -s b -e c
     info Pipeline 'chain': 2 main steps in 2 layers, 0 teardown steps
  success Pipeline completed: 2 steps completed, 0 skipped in 734ms
```

On a diamond, a window that runs through one branch drops the other: `-s b -e d` on `a→{b,c}→d`
keeps `b` and `d`, and `d` depends on `b` alone. If the two ends do not meet — `-s c -e b` on
`a→b→c` — nothing qualifies, and the run stops with `No steps to execute after applying filters`.

### Resume

`--resume` replays the step set the prior run planned and skips what completed:

```console
$ flowrs run liar -i input -w work4 -t res1 --resume
  success Pipeline completed: 2 steps completed, 4 skipped in 690ms
```

It is mutually exclusive with `-s`/`-e`/`-k` — those derive a fresh sub-DAG, while resume
inherits the slice the prior run recorded:

```console
$ flowrs run liar ... -e prepare --resume
error: the argument '--end-step <END_STEP>' cannot be used with '--resume'
```

**Parameters baseline from `params.json`,** so a resumed run agrees with the steps it is
continuing. Your `-p`/`-c` still win, and any genuine change is reported:

```console
$ flowrs run liar ... --resume -p message=changed
  warning Resuming from /tmp/work4/res1 with 1 parameter override(s):
  warning   MESSAGE: hello → changed
     info Resuming from prior run (finished: 2026-08-24T05:13:14Z, same version)
```

A warning is not always enough. If an override changes a parameter that an **already-completed**
step's `cache_key` covers, resume refuses: that step's kept results came from the old value while
everything downstream would use the new one, leaving a directory attributable to no single parameter
set.

```console
$ flowrs run liar ... --resume -p quality=55
  warning   QUALITY: 20 → 55
    error Validation error: Cannot resume: 1 override(s) change a parameter that an
    already-completed step's cache_key covers:

  QUALITY (completed step 'analyze')

Those steps ran under the old values and their results are being kept, so the run would mix
results from two different parameter sets.

Re-run without `--resume` to start fresh under the new values, or pass `--force` if the
change only affects steps that have not run yet.
```

`readonly` params resolve from the current manifest's defaults, including profile overrides,
instead of replaying their recorded values. A recorded baseline does not trip the readonly gate.
An explicit `-p` or `-c` on one is refused, even when it restates the recorded value. An author's
changed default therefore carries into the resumed run.

A **changed input directory** is refused on the same grounds, for pipelines declaring a `cache_dir`.
Completed steps read the old tree, so continuing over a new one mixes two input sets in one
directory:

```console
$ flowrs run qc -i sample_B -w work -t run1 --resume
    error Validation error: Cannot resume: the input directory changed since this run started.

The completed steps belong to the earlier input set, so resuming would mix two input sets in one
directory.

Re-run without `--resume` to start fresh over the new inputs, or pass `--force` if the
change only affects steps that have not run yet.
```

#### What resume checks, and what it does not

Every run records a **version fingerprint**: the engine version and your `pipeline.version`. On
`--resume` that is compared against the prior run's before anything else is read.

- **Fingerprint differs** → the recorded state is discarded whole and the pipeline runs from the
  start. Bumping `pipeline.version` is your signal that this is not the pipeline that produced the
  directory, so nothing old is replayed. This is how to resume after restructuring params or steps.
- **Fingerprint matches** → the recorded params are replayed as the baseline, and a recorded param
  the manifest no longer declares is a hard error naming it. With the version unchanged you have
  said this is the same pipeline, so the mismatch is more likely a forgotten bump than an intended
  change.

```console
$ flowrs run vp -i in -w work -t task001 --resume
  warning Version changed (prior: engine=1.11.0, pipeline=0.1.0; current: engine=1.11.0, pipeline=0.2.0)
     info Version changed, running full pipeline
```

If you edit a step script, bump `pipeline.version` or start a fresh task before relying on resumed
results. Use caching when you need step outputs to be reused safely across runs.

### Caching

`cache = true` reuses a step's results across runs. The pipeline must declare `cache_dir`, and
the step writes to `${CACHE_DIR}` instead of `${OUT_DIR}`:

```toml
[pipeline]
name = "full"
version = "0.2.0"
cache_dir = "shared"

[steps.analyze]
exec = "analyze.sh"
label = "Analyze"
depends_on = ["prepare"]
cache = true
cache_key = ["quality"]
outputs = ["${CACHE_DIR}/analysis.txt"]
```

`CACHE_DIR` resolves to `WORK_DIR/shared` — outside any task directory, which is what lets
separate runs share it. First run computes; the second finds the entry:

```console
$ flowrs run full -i input -w work2 -t run2 -@ 4
   cached 26/08/24 13:10:10 [analyze] outputs reused
  success Pipeline completed: 5 steps completed, 0 skipped, 1 from cache in 2s
```

One line per hit, and `cached` rather than `skipped` because the two mean opposite things: a skipped
step produced nothing, a cached one's outputs are on disk. `status.json` records `cached`, but no
cache-entry path. Scripts locate shared results through `${CACHE_DIR}` or, for scattered work,
`${ITEM_DIR}`.

**Declare everything you write.** Every file a step produces must appear in its `outputs` — that is
what the run checks on a hit, what a later run trusts, and what `${CACHE_DIR}` names. A script that
writes into `$CACHE_DIR` without declaring the path is outside everything the engine can check: the
cache key is the correctness boundary, and the manifest is the only place a value crosses it. Writing
a pool file the manifest does not mention can overwrite what another step's entry vouches for, and
that entry will still be served as a hit.

**An entry is invalidated by:**

- **the step's executable** — edit the script, the entry is gone
- **the input directory** — changing the inputs invalidates the entry
- **the values of its `cache_key` parameters** — `-p quality=30` re-runs the step
- **the cache identity of its cached upstreams** — invalidating one invalidates everything after
- **uncached intermediate steps** between a cached step and its cached upstream

`cache_key` is deliberately _not_ every resolved parameter: hashing all of them would invalidate a
QC step because an unrelated downstream threshold changed. The list is your statement of what the
step actually reads. Names are case-insensitive. Executable content and cached-upstream identity are
always included, so editing a script or invalidating an upstream needs nothing declared.

#### The input directory

Cache entries are tied to the input directory used by the run. Adding, removing, or changing input
files invalidates cached results, so a run over one dataset cannot silently reuse results from
another. If you want a clean result after a meaningful input change, start a new task.

**A `cache_key` param must not be `readonly`**, and the manifest is rejected if one is: `--resume`
re-resolves a readonly param from the manifest while the drift check only inspects `-p`/`-c`, so
editing a readonly default would change a cache-key value with nothing watching.

#### Sharing one cache directory

`cache_dir` is a shared pool, and sharing it between pipelines is the point: a `reference` step
under one manifest and a `reference` step under another with the same key reuse one copy. What the
pool guarantees is bounded by the cache key, so the rule for concurrent runs over one workspace is:

> **Two runs over one `cache_dir` must agree on the cache key of every step they share.**

Two runs with the same key write identical bytes, so a writer overwriting a reader's outputs is
idempotent. Two runs with *different* keys for the same step are what to avoid: the key is the only
thing separating them, and its outputs are still flat in one directory, so a run that adopted the
entry under key K1 can have its files replaced by a run writing K2 for the same step before its
downstream reads them. Writers are serialised by the `.partial` lock, but nothing stops a writer
from covering what a reader already adopted.

In practice that means an invocation differing in `-p`, `-c`, or `-i` needs its own `-w`
(the run claim already refuses a second run sharing one `out_dir`, so two runs in one directory need
distinct `-t`). Beyond that, the keys must differ only where the manifests genuinely produce the
same outputs.

### Signals

`SIGINT`, `SIGTERM`, `SIGHUP`, and `SIGQUIT` cancel the run: running steps are killed as a process
group, and the run exits `128 + N` — `130` for Ctrl-C. `SIGKILL`, a machine reset, and power loss
cannot be handled.

What still runs after the signal is narrower than it looks:

| | On a cancelled run |
| --- | --- |
| steps not yet started | recorded `skipped` with reason `cancelled`; never spawned |
| **teardown steps** | **do not execute** — they reach the same already-cancelled check and are recorded without running |
| `on_error` hooks | do not fire — you stopped the run, which is not a fault |
| **`on_failure` hooks** | **run to completion**, uninterrupted by the signal |
| system cleanup | the claim is released and a package's decrypted tree is removed; scratch survives |

So `on_failure` is the only *authored* work guaranteed to happen after a Ctrl-C, and it is there to
report the ending, not to clean up: `$EXIT_CODE` is `128 + N` and `status.json` carries
`cancelled_by`.

`128 + N` assumes nothing else failed first. A run that failed with its own exit code and was *then*
cancelled reports that code, the more specific fact — `cancelled_by` records the signal either way.

`--keep-tmp` prints the retained scratch path at the end of the run, which saves reconstructing the
unique directory name.

---
