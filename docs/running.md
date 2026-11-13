# Running

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>] [options]
```

`<PIPELINE>` is a registered name, a pipeline directory, or a `.flowpkg`.

| Flag | Effect |
| --- | --- |
| `-i, --input-dir` | Existing input directory with read and search (execute) permission |
| `-w, --work-dir` | Work directory; created after validation if absent |
| `-t, --task-id` | Put this run's results in `WORK_DIR/TASK_ID/`; otherwise use `WORK_DIR/` |
| `-p, --param` | Supply `KEY=VALUE`; repeat for more parameters |
| `-c, --config` | Read parameters from JSON, TOML, or `KEY=VALUE` lines |
| `-@, --threads` | Set the run's thread budget |
| `--max-in-flight` | Limit concurrent items of one scattered step |
| `-s, --start-step` | Keep this step and its descendants |
| `-e, --end-step` | Keep this step and its ancestors |
| `-k, --skip-steps` | Skip named steps |
| `--resume` | Continue the recorded run |
| `--force` | With resume, permit input or cache-key parameter changes |
| `--tmp-dir` | Choose a scratch base for step temporary files |
| `--keep-tmp` | Retain scratch after success, failure, or handled cancellation |
| `-q` / `-v` / `-vv` | Quiet / include debug / include trace messages |

## Inspect a pipeline

```bash
flowrs inspect guardian
flowrs inspect guardian --json
flowrs inspect guardian -v
```

Inspection starts with the pipeline name, version, state (`plaintext`, `packaged`, or `protected`),
description, author, and source path. A packaged pipeline also reports its build timestamp and
required FlowRs version. Dates are shown only when known; a package build is not a last-edit date.

Protected packages have an `Authorization` section before their manifest details. It reports the
server and customer names, release ID, machine permission, grant scope, and access expiry with time
remaining. Access ends at the earlier customer or grant expiry. Dates include the local UTC offset.
A limited grant reports occupied run slots; a full quota still permits inspection. `-v` adds IDs,
client MAC/IP, key scheme, and the content fingerprint.

An access refusal preserves the basic metadata and ends after `Authorization` with the error on
stderr. `Denied` means the server checked and refused access; `Could not check` means configuration,
connectivity, or package verification prevented the check. A corrected configuration or publisher
assistance may be needed before manifest details can be shown.

Successful inspection continues with `Pipeline` settings, then steps, parameters, constraints,
errors, and hooks. The displayed source is the supplied directory or package, never a temporary
extraction directory. Inspection does not execute pipeline steps, detectors, or hooks.

`--json` uses the same top-level manifest fields for every source, including `name`, `version`,
`steps`, and `parameters`, plus `type` and `source`. Package metadata adds `built` when known and
`requires_flowrs`. Protected sources add `authorization`; its `status` is `authorized`, `denied`,
or `unavailable`. Expiry fields are Unix timestamps. A protected failure emits one diagnostic
envelope with the readable metadata in `inspection`; unopened manifest fields are omitted.
Use the process exit code or envelope `exit_code` to determine success. Other failures use the
ordinary diagnostic envelope. `--check-environment` retains its separate host-check report.

## Slices

For a chain `prepare -> analyze -> report`, run only the last two steps:

```bash
flowrs run demo -i input -w work -t slice -s analyze -e report
```

Combining `-s` and `-e` keeps the intersection of their selections. Dependencies outside the
selection are removed. Supply any inputs the omitted steps would have produced.
If the selected step is a gather, its scattered producers remain only as manifest inputs: their
per-item outputs must already exist in the same task directory, and the producers are not rerun.

`-k` keeps the graph but marks the named steps skipped; downstream trigger rules still apply.
Unknown step names and empty selections are refused. Teardown steps are separate from the
`-s`/`-e` selection.

## Resume

Use the same pipeline name, work directory, and task id:

```bash
flowrs run demo -i input -w work -t run001 --resume
```

### What Resume Compares

FlowRs records a fingerprint of the complete `-i` tree and compares it with the current tree
when resuming. A difference refuses the resume unless `--force` is given.

Keep `-w` outside `-i`. If the work directory is inside the input directory, the run's own
outputs, logs, and `status.json` become part of the input tree. By default, scratch is under the
output directory too. These files change as the run proceeds, so a later `--resume` sees a
different input fingerprint. If `--tmp-dir` is set, keep that path outside `-i` as well.

Resume applies to the same pipeline name and the same output directory selected by `-w` and `-t`.
It also refuses a changed collection identity or profile selector. Use a new work directory or
task ID to start anything else.

Resume uses the prior run's selected steps and recorded parameters. It cannot be combined with
`-s`, `-e`, or `-k`. Completed uncached steps are retained; cached steps check their cache entries.
Teardown steps run again.

`status.json` records the accepted parameters in `params`, alongside pipeline identity and results.
Names are uppercase and values are strings, matching the step environment. Parameters and initial
execution state are written atomically after resume checks pass. A refused resume preserves the
prior terminal status, parameters, and step results; failure-hook executions may still be appended.
If no parameter set was accepted, `params` is absent; start without `--resume` to resolve parameters
afresh.

Explicit `-p`/`-c` values override recorded parameters. Readonly parameters resolve from the
current manifest, including profile defaults; explicit overrides of them are refused. If a readonly
value differs from the recorded value, resume warns that completed steps may retain results from the
old value. Bump `pipeline.version` to start a full run under the new value.

The manifest's `pipeline.name` must match the recorded run. A different name is refused even
with `--force` or changed versions; use the original pipeline or start a fresh task.

An engine or `pipeline.version` change starts a full run in the existing output directory.
With versions unchanged, these checks apply:

| Change since the prior run | Result |
| --- | --- |
| Recorded parameter was removed | Refuse resume |
| Profile-selector value changed | Refuse, including with `--force`; remove the override or rerun from scratch |
| A cache-key parameter changed while its producer or a descendant has retained completed results | Refuse unless `--force` is supplied |
| Input fingerprint changed | Refuse unless `--force` is supplied |
| Parsed collection identity changed | Refuse, including with `--force`; restore it or start a fresh task |

`--force` does not recompute retained completed steps. Use it only when you accept a directory
containing results from different inputs or parameter values. A fresh task is preferable when
those results must agree.

Resume does not detect arbitrary script or library edits. Bump `pipeline.version` or start a
fresh task after changing pipeline behavior. Use a new cache directory too if the change is
outside cache tracking.

## Caching

Declare a shared cache directory and the files a cached step produces:

```toml
[pipeline]
name = "demo"
version = "1.0.0"
cache_dir = "shared"

[params.quality]
type = "integer"
default = 20

[steps.analyze]
exec = "analyze.sh"
label = "Analyze inputs"
cache = true
cache_key = ["quality"]
outputs = ["${CACHE_DIR}/analysis.txt"]
```

Here `CACHE_DIR` is `WORK_DIR/shared`, outside individual task directories. Write cached scalar
results below it. Cached scattered results use a path below `${ITEM_DIR}`; the item directory root
itself is not an output. Declare the files or directories needed for reuse in `outputs`; a cache
hit checks that these paths exist. The declared output scope is part of cache identity, so changing
the paths creates a new cache entry. The step's status is `cached`, not `skipped`.

Each cache slot has a `.partial` claim marker and a `.done` publication marker. The `.done` file
contains the `cache_key` and its publication `generation` together, so a reader observes one
atomic record; FlowRs does not create a separate cache-key file.

Cache identity tracks executable content, listed `cache_key` values, declared output scope and
paths, input metadata, and upstream execution identities. Pipeline and step names and versions are
not hashed, so differently named steps can share an entry when their contracts match. List every
parameter that affects the result; readonly parameters cannot be cache keys.

Input tracking uses relative paths, file sizes, and modification times rather than file-content
hashes. Directory names and regular-file symlink targets also contribute; common OS metadata files
are ignored. An edit preserving size and modification time can escape detection.

Imported libraries, external tool versions, thread counts, other environment values, and parameters
omitted from `cache_key` are outside this tracking. The engine assumes output depends only on the
executable, declared parameter values, inputs, and upstream identities. Keep other influences out
of cached output or manage invalidation yourself. After such a change, use a new cache directory or
remove the affected cached results. A new task id alone does not invalidate the shared cache.

### Sharing one cache directory

Compatible runs can reuse one cache directory. Writers may replace an entry while another run
uses it. The engine checks the consumed publications before and after each executing step,
including teardown, and fails the affected run with `CACHE_INPUT_CHANGED` (121) if one changed.
A replacement is detected even if the original cache key is restored. Affected consumers do not
publish derived cache entries; rerun after resolving the conflict. These checks detect replacement
rather than locking readers, and do not undo a step's external side effects.

Scattered cache hits copy their declared outputs into the task's item directory and check the
publication again after the complete copy. A replacement during restoration fails the item with
`CACHE_INPUT_CHANGED` (121) and removes its incomplete restored outputs. Other steps' files in
the same item directory are preserved, and scattered siblings finish normally. This check also
applies when restoring cached outputs for a skipped or resumed step.

## Signals and scratch

`SIGINT`, `SIGTERM`, `SIGHUP`, and `SIGQUIT` cancel a run and stop its running step processes.
The exit code is normally `128 + signal` (`130` for Ctrl-C); an earlier failure can retain its
own code. `status.json` records `cancelled_by`. A second signal forces exit without waiting for
hooks or writing a final `status.json`.

Cache filesystem operations have a five-minute idle limit; copying another chunk resets it.
Cancellation or an idle timeout gives the worker five seconds to stop and clean up. If a filesystem
call remains stuck, FlowRs kills its child process groups and exits (`128 + signal` for cancellation,
70 for an idle timeout). It retains claims and scratch because releasing them while a worker can
still write would permit overlapping runs. A second signal also retains them when cache I/O is
active; otherwise it attempts cleanup. Restore filesystem access, verify the previous processes
have exited, then use `--resume` to recover the stale run claim. This forced exit may leave
`status.json` incomplete. An uninterruptible kernel I/O wait can delay actual process death even
after termination is requested.

Pending main and teardown steps do not start after cancellation. Cancellation does not fire
`on_error`; `on_failure` runs once the lifecycle has started. Admitted hooks are allowed to finish,
including queued error-hook batches, with each script's timeout starting when it executes.
`SIGKILL`, power loss, and machine resets cannot be handled.

FlowRs attempts to remove scratch on success, failure, and handled cancellation unless the
invocation included `--keep-tmp`. Supply it before reproducing a failure:

```bash
flowrs run demo -i input -w work -t debug --keep-tmp
```

The retained scratch path is printed at the end. Logs and declared persistent outputs remain
available without this flag.
