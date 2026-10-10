---
name: flowrs-author
description: "Writes, reads, and runs FlowRs workflow-engine pipelines (TOML manifests plus step scripts). Use for pipeline authoring, inspection, validation, packaging, and execution. Not for developing FlowRs itself or for Snakemake, Nextflow, WDL, or CWL projects."
---

You write and run FlowRs pipelines for a user. Use this directory as the operating reference; check the installed binary's help for CLI details.

## Trigger

Use this skill to create, read, edit, validate, package, inspect, or run a FlowRs pipeline.
Do not use it to develop FlowRs itself or for a different or unspecified workflow engine.

## Files

- Treat `manifest.toml` as the pipeline declaration.
- Put step executables in `steps/`; put detector executables in `bin/`; put hook executables in
  `hooks/`.
- Read [references/manifest.md](references/manifest.md) before writing or changing a manifest.
- Read [references/stdlib.md](references/stdlib.md) before writing or changing a step, detector, or hook script.
- Read [references/running.md](references/running.md) before choosing a run, inspect, compile, package, slice, resume, or
  cache command.
- Read [references/exit-codes.md](references/exit-codes.md) before interpreting a non-zero command or a JSON diagnostic.
- Read [references/status-json.md](references/status-json.md) before consuming a run result.
- Read [assets/manifest-v1.json](assets/manifest-v1.json) for field names and value shapes. Use `flowrs compile PIPELINE_DIR --json`
  to check semantic constraints, including parameter type consistency and graph validity.

## Read Procedure

1. Read `manifest.toml` or use `flowrs inspect PIPELINE --json` for a package or registered name.
   Follow `references/manifest.md` to identify inputs, parameters, dependencies, scatter/gather,
   cached outputs, and teardown work.
2. For a directory, follow each `exec` into `steps/`, each detector into `bin/`, and hook names
   into `hooks/`. Read imported pipeline libraries to understand effects the manifest does not describe.
3. Use `flowrs inspect PIPELINE --check-environment --json` on the intended run machine to check
   declared dependencies. This checks presence, not tool versions or complete runtime readiness.
4. For an existing run, read its `params.json`, `status.json`, and relevant unit logs. Use the
   status reference to distinguish cached, skipped, completed, and failed work before resuming.

## Write Procedure

1. Identify the pipeline name, version, inputs, outputs, parameters, tools, and requested steps.
2. For a new pipeline, run `flowrs create NAME` and edit the generated directory. For an
   existing pipeline, preserve its generated stdlib and language configuration.
3. Read `references/manifest.md` and `assets/manifest-v1.json`.
4. Create [pipeline], one [steps.<name>] table per logical step, and [params.<name>] tables
   for values that vary by run.
5. Create a file for each `exec`, detector, and hook name; direct executables need execute permission. Keep `exec` values as bare
   filenames; path separators and `..` are invalid.
6. Read `references/stdlib.md`. Write declared outputs under an allowed engine directory and use
   `die` for failures that the manifest names.
7. Run `flowrs compile PIPELINE_DIR --json`. Parse stdout as JSON and fix the diagnostics whose
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
  and audit reactions in hooks; hook failure does not change the run result.
- Use `scatter` for one logical step over a declared collection and `gather` for a step that waits
  for the named scattered batches to finish. Scope scattered outputs to `${ITEM_DIR}`.
- Use `cache = true` only with `[pipeline].cache_dir`, declare cached outputs needed for reuse, and list
  the parameters that affect the results in `cache_key`.
- Use `--max-in-flight` for a scattered queue bound. Use `-@` for the run's thread budget; the
  effective concurrency is constrained by both.
- Supply a parameter with `-p KEY=VALUE` or `-c FILE` when no detector, profile default, base
  default, or resume baseline can provide it.
- For engine failures, interpret `77` as an unusable licence, `79` as an unusable package grant,
  `78` as an invalid manifest, and `64` as an invalid invocation or supplied value. Steps can
  return these numbers too; check their records in `status.json`.

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
