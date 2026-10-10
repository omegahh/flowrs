# Running

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>] [options]
```

`<PIPELINE>` is a registered name, a pipeline directory, or a `.flowpkg`.

| Flag | Effect |
| --- | --- |
| `-i, --input-dir` | Existing input directory; scripts must treat it as read-only |
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
| `--tmp-dir` | Choose a scratch base, such as `/dev/shm` |
| `--keep-tmp` | Retain scratch after success, failure, or handled cancellation |
| `-q` / `-v` / `-vv` | Quiet / include debug / include trace messages |

## Slices

For a chain `prepare -> analyze -> report`, run only the last two steps:

```bash
flowrs run demo -i input -w work -t slice -s analyze -e report
```

Combining `-s` and `-e` keeps the intersection of their selections. Dependencies outside the
selection are removed. Supply any inputs the omitted steps would have produced.

`-k` keeps the graph but marks the named steps skipped; downstream trigger rules still apply.
Unknown step names and empty selections are refused. Teardown steps are separate from the
`-s`/`-e` selection.

## Resume

Use the same work directory and task id:

```bash
flowrs run demo -i input -w work -t run001 --resume
```

Resume uses the prior run's selected steps and recorded parameters. It cannot be combined with
`-s`, `-e`, or `-k`. Completed uncached steps are retained; cached steps check their cache entries.
Teardown steps run again.

Explicit `-p`/`-c` values override recorded parameters. Readonly parameters resolve from the
current manifest, including profile defaults; explicit overrides of them are refused.

An engine or `pipeline.version` change starts a full run in the existing output directory.
With versions unchanged, these checks apply:

| Change since the prior run | Result |
| --- | --- |
| Recorded parameter was removed | Refuse resume |
| Profile-selector value changed | Refuse, including with `--force`; remove the override or rerun from scratch |
| A cache-key parameter changed while its producer or a descendant has retained completed results | Refuse unless `--force` is supplied |
| Input fingerprint changed, for a pipeline declaring `cache_dir` | Refuse unless `--force` is supplied |
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
results there. Cached scattered results use `${ITEM_DIR}`. Declare the files needed for reuse in
`outputs`; a cache hit checks that these paths exist. The step's status is `cached`, not `skipped`.

Cache identity tracks executable content, listed `cache_key` values, input metadata, and relevant
upstream step identities. List the parameters that affect the result; readonly parameters cannot
be cache keys.

Input tracking uses relative paths, file sizes, and modification times rather than file-content
hashes. Directory names and regular-file symlink targets also contribute; common OS metadata files
are ignored. An edit preserving size and modification time can escape detection.

Imported libraries, external tool versions, and parameters omitted from `cache_key` are outside
this tracking. After such a change, use a new cache directory or remove the affected cached results.
A new task id alone does not invalidate the shared cache.

### Sharing one cache directory

Compatible runs can reuse one cache directory. Avoid concurrent runs that write different results
to the same cached output paths. Replacement detected between steps stops a run with
`CACHE_INPUT_CHANGED` (121); rerun after resolving the conflict. Replacement during a step's
file read may escape that check.

## Signals and scratch

`SIGINT`, `SIGTERM`, `SIGHUP`, and `SIGQUIT` cancel a run and stop its running step processes.
The exit code is normally `128 + signal` (`130` for Ctrl-C); an earlier failure can retain its
own code. `status.json` records `cancelled_by`.

Pending main and teardown steps do not start after cancellation. Cancellation does not fire
`on_error`; `on_failure` runs once the lifecycle has started. Started hooks are allowed to finish,
subject to their timeout. `SIGKILL`, power loss, and machine resets cannot be handled.

FlowRs attempts to remove scratch on success, failure, and handled cancellation unless the
invocation included `--keep-tmp`. Supply it before reproducing a failure:

```bash
flowrs run demo -i input -w work -t debug --keep-tmp
```

The retained scratch path is printed at the end. Logs and declared persistent outputs remain
available without this flag.
