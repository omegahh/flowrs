---
name: flowrs-author
description: "Use when creating, editing, validating, packaging, inspecting, registering, or running a FlowRs pipeline, or reading its status and diagnostics. This includes requests mentioning flowrs, manifest.toml, .flowpkg, or the scaffold's steps/bin/hooks. Do not use for developing the FlowRs engine or for Snakemake, Nextflow, WDL, or CWL workflows."
---

Use this directory as the operating reference for FlowRs pipeline work. Check the installed
binary's help when a flag or command detail is not covered here.

## Trigger boundary

Use this skill for a FlowRs pipeline even when the user describes the task by its files or result
instead of naming FlowRs: a manifest, scaffold, `.flowpkg`, detector, hook, run directory,
`status.json`, or FlowRs diagnostic is enough. Do not use it for changes to the FlowRs Rust engine,
its tests, or its documentation; those are repository-development tasks.

## Task routing

Read only the references needed for the current operation. Each reference is directly linked from
this file so detailed material stays out of the initial context.

| Task | Read before acting |
| --- | --- |
| Create or change `manifest.toml`, parameters, collections, scatter/gather, cache, hooks, or errors | [references/manifest.md](references/manifest.md) and [assets/manifest-v1.json](assets/manifest-v1.json) |
| Create or change a step, detector, or hook executable | [references/stdlib.md](references/stdlib.md) |
| Create, compile, inspect, package, register, license, slice, resume, cache, or run a pipeline | [references/running.md](references/running.md) |
| Interpret a non-zero command, `--json` output, or diagnostic envelope | [references/exit-codes.md](references/exit-codes.md) |
| Read a completed or interrupted run | [references/status-json.md](references/status-json.md) |

Use `flowrs compile PIPELINE_DIR --json` as the semantic validator. The schema asset supplies field
names and value shapes; the compiler supplies cross-field and graph validation.

## Workflow

1. Identify the source (directory, registered name, or `.flowpkg`) and the requested operation.
2. Read the routed reference before editing or executing. For an unfamiliar source, use
   `flowrs inspect PIPELINE --json`; for a host check, add `--check-environment`.
3. For a directory, inspect `manifest.toml`, then follow each step `exec` under `steps/`, detector
   under `bin/`, and hook under `hooks/`. Read imported libraries when they affect behaviour.
4. For authoring, preserve the generated stdlib and language configuration. Create a new scaffold
   with `flowrs create NAME`; use `flowrs create NAME --update` only to refresh binary-owned files.
   Keep each step, detector, and hook value as a single filename; mark directly launched files
   executable.
5. After manifest or executable changes, run `flowrs compile PIPELINE_DIR --json`. Parse JSON from
   stdout only; progress remains on stderr. Fix diagnostics by `code` and `field`, not by matching
   advisory prose.
6. Run only the requested pipeline operation. Inputs need read and search access; the work
   directory is created after validation when absent:
   `flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR`.
7. After a run, read [references/status-json.md](references/status-json.md) and use the step,
   item, hook, and failure records to report the outcome. With `-t TASK_ID`, the record is
   `WORK_DIR/TASK_ID/status.json`.

## Non-obvious contracts

- `run` has no `--json`. `compile --json`, `inspect --json`, and `registry list --json` are the
  machine-readable command interfaces; a run's machine-readable result is `status.json`.
- A directory and a plaintext package do not consult a licence. An encrypted package requires both
  a valid licence and a matching `pipeline_grants[PIPELINE_NAME]` entry.
- A process that exits 0 still fails when a declared output is missing. Do not infer success from
  the process code alone.
- Hooks are notifications and do not hold thread permits; hook failure does not change the run
  result. Put delivery work whose failure matters in a step, usually a teardown step.
- `--max-in-flight` caps items of one scattered logical step. `-@` is the shared thread budget;
  effective concurrency is limited by both. Scattered outputs must be scoped to `${ITEM_DIR}`.
- Cache identity includes executable bytes, tracked input metadata, declared cache-key parameters,
  collection identity, and relevant upstream identities. A new task id does not repair untracked
  changes; change or clear the cache directory when an untracked dependency changes.
- Parameter resolution is `readonly gate > -p/-c > detected > profile default > base default >
  unset`. Supply `-p KEY=VALUE` or `-c FILE` when no earlier tier can provide a required value.
- `64` means fix the invocation or supplied value; `78` means fix the manifest; `77` means repair
  the licence; `79` means obtain a package grant. A step can return these numbers too, so use its
  `status.json` record to identify the source.

## Minimal pipeline

Create a scaffold first:

```bash
flowrs create hello
cd hello
```

Edit the generated manifest:

```toml
[pipeline]
name = "hello"
version = "1.0.0"

[steps.hello]
exec = "hello.sh"
label = "Write greeting"
outputs = ["${OUT_DIR}/hello.txt"]

[params.message]
type = "string"
default = "hello"
```

Edit `steps/hello.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$(get_config message)" > "${OUT_DIR}/hello.txt"
```

Validate and run it:

```bash
mkdir -p input work
flowrs compile . --json
flowrs run . -i input -w work -t run001
```

## Boundaries

- Do not invent manifest keys. Unknown fields are errors; consult the schema asset.
- Do not put secrets in parameters; resolved values are recorded in `params.json`.
- Do not treat a hook as a dependency or delivery guarantee.
- Do not treat an item id as a filesystem path component; use `${ITEM_DIR}` and the engine-provided
  item metadata.
