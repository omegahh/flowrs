# Operator guide

This guide covers installation, running a pipeline, and checking its result.
A FlowRs pipeline is a TOML manifest plus scripts: the manifest names steps, their dependencies,
parameters, and expected outputs. Authors start with the [pipeline author guide](authoring.md).

## Install

FlowRs releases provide a static Linux x86_64 binary. Download the archive from the
[releases page](https://github.com/omegahh/flowrs/releases), unpack it, and put the binary on your
`PATH`:

```bash
tar xzf flowrs-*.tar.gz
sudo install -m755 flowrs /usr/local/bin/flowrs
flowrs --version
```

Shell completions are in the archive under `completions/`. To build from source,
`cargo build --release` writes `target/release/flowrs`.

## Run a pipeline

The basic invocation is:

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>]
```

`<PIPELINE>` may be a registered name, a pipeline directory, or a `.flowpkg` supplied by its
publisher. Some packages need publisher-provided access on this machine; contact the publisher if
FlowRs reports an access or package-opening failure. The input directory must exist and allow read
and search access; the work directory is created after validation if absent.
Use `-t` when several runs share one work directory; each task gets its own output directory.

For parameters and run controls, see [Running](running.md). For a pipeline directory, a useful
preflight is:

```bash
flowrs inspect <PIPELINE> --check-environment
```

## Read the result

After setup, run files are under the work directory. Early validation refusals can leave no record;
parameter-resolution failures can leave `status.json` without `params.json`:

```text
<work>/<task>/status.json   # machine-readable run and step results
<work>/<task>/params.json   # resolved parameter values
<work>/<task>/logs/          # captured output from launched units
<work>/<task>/tmp/           # scratch base; use --keep-tmp to retain scratch
```

Without `-t`, these files are directly under `<work>/`. `--tmp-dir` selects a different scratch
base.

`status.json` is the file for automation. Its `schema_version` identifies the document format;
optional fields are absent when they do not apply. The top-level `status` is `running`,
`completed`, or `failed`. Each step records its status, timing, exit code when it ran, and any
failure or skip reason. Scattered steps also record their item results.

Use [Resume](running.md#resume) to continue a prior run. Review changes before using `--force`:
it permits retained and new results to come from different inputs or parameter values.

Console output is a summary. Files under `logs/` capture stdout and stderr from launched
steps, detectors, hooks, and scattered items. Cached or skipped work may have no new log.
Use these for diagnosis, and [exit codes](exit-codes.md) for scripts that classify failures.

## Manage runs

- Use `--resume` to continue a prior run and reuse completed work. A changed pipeline or input set
  normally requires a fresh task.
- Use `cache = true` in the manifest to reuse declared step outputs across runs. The cache is
  described in [Running](running.md#caching).
- Use the registry commands to give packages stable names:
  `flowrs registry add demo.flowpkg --name demo`, `flowrs registry list`, and
  `flowrs registry remove demo`. A registered package can then be passed to `flowrs run` by name.
- Include `--keep-tmp` in the run command when you need scratch retained for investigation.

Pipeline authors should continue with the [pipeline author guide](authoring.md), then the
[manifest reference](manifest-reference.md).
