---
name: flowrs-author
description: "Writes and runs FlowRs workflow-engine pipelines (TOML manifests plus step scripts). Use when the user asks to create, edit, or execute a FlowRs pipeline. Don't use for Snakemake, Nextflow, WDL, or CWL projects."
---

You write and run FlowRs pipelines for a user. These files are your entire operating knowledge.

## Trigger

Use this skill when the user names FlowRs or asks to create, edit, validate, package, inspect, or
run a FlowRs pipeline. Do not use it for Snakemake, Nextflow, WDL, CWL, or an unspecified workflow
engine.

## Files

- Treat `manifest.toml` as the pipeline declaration.
- Put step executables in `steps/`; put detector executables in `bin/`; put hook executables in
  `hooks/`.
- Read `references/manifest.md` before writing or changing a manifest.
- Read `references/stdlib.md` before writing or changing a step, detector, or hook script.
- Read `references/running.md` before choosing a run, inspect, compile, package, slice, resume, or
  cache command.
- Read `references/exit-codes.md` before interpreting a non-zero command or a JSON diagnostic.
- Read `references/status-json.md` before consuming a run result.
- Read `assets/manifest-v1.json` for field names and value shapes. Use `flowrs compile --json`
  to check semantic constraints, including parameter type consistency and graph validity.

## Write Procedure

1. Identify the pipeline name, version, inputs, outputs, parameters, tools, and requested steps.
2. For a new pipeline, run `flowrs create NAME` and edit the generated directory. For an
   existing pipeline, preserve its generated stdlib and language configuration.
3. Read `references/manifest.md` and `assets/manifest-v1.json`.
4. Create [pipeline], one [steps.<name>] table per logical step, and [params.<name>] tables
   for values that vary by run.
5. Create one executable file for every `exec`, detector, and hook name. Keep `exec` values as bare
   filenames; path separators and `..` are invalid.
6. Read `references/stdlib.md`. Export declared outputs under an allowed engine directory and use
   `die` for failures that the manifest names.
7. Run `flowrs compile PIPELINE_DIR --json`. Parse stdout as JSON and fix every diagnostic whose
   `code` is reported. Human progress remains on stderr.
8. Run `flowrs inspect PIPELINE_DIR --json` when a machine-readable manifest projection or
   environment check is needed. `inspect --json` emits the projection on success and a diagnostic
   envelope on failure.
9. Read `references/running.md`; use an existing input directory. The work directory is created
   after validation when absent:
   `flowrs run PIPELINE -i INPUT_DIR -w WORK_DIR`.
10. Read `references/status-json.md`; parse `WORK_DIR/status.json`, or
    `WORK_DIR/TASK_ID/status.json` when `-t TASK_ID` was used.
11. If the run fails, read `references/exit-codes.md`, then use the step name, status, exit code,
    and diagnostic `code` to choose the fix. Do not parse human `message` or `hint` text.

## Required Decisions

- Put work whose failure must fail the run in a step or `teardown = true` step. Put notifications
  and audit reactions in hooks; hook failure never changes the run result.
- Use `scatter` for one logical step over a declared collection and `gather` for a step that waits
  for every instance. Scope scattered outputs to `${ITEM_DIR}`.
- Use `cache = true` only with `[pipeline].cache_dir`, declare every cached output, and list only
  the parameters the step reads in `cache_key`.
- Use `--max-in-flight` for a scattered queue bound. Use `-@` for the run's thread budget; the
  effective concurrency is constrained by both.
- Supply a parameter with `-p KEY=VALUE` or `-c FILE` when no detector, profile default, base
  default, or resume baseline can provide it.
- Treat `77` as an unusable licence for a protected package, `79` as a missing grant for a protected package, `78` as an
  invalid manifest, and `64` as an invalid invocation or supplied value.

## Minimal Pipeline

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
- Do not use a global `--json` flag. JSON output is declared on `compile`, `inspect`, and
  `registry list` only.
- Do not treat a hook as a dependency or as delivery work.
- Do not infer success from process exit `0` when declared outputs are missing; read `status.json`.
- Do not put secrets in parameters; resolved values are recorded in `params.json`.
