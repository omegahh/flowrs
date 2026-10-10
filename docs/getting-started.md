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

## Install a licence for protected packages

**Plaintext runs need no licence.** A pipeline directory and a plain `.flowpkg` run without one. A
protected `.flowpkg` needs a valid licence and a grant for that package.

FlowRs searches these paths in order and uses the first file that validates:

1. `./flowrs.license`
2. `./license.json`
3. `/etc/flowrs/license.json`
4. `~/.flowrs/license.json`

Ask the licence issuer which machine identity to send:

```bash
flowrs license fingerprint
```

A machine identity can change after a hardware replacement or operating-system reinstall. If the
licence restricts machines, ask the issuer to reissue it with the new identity.

Install the file they return:

```bash
flowrs license add ./your-licence-file
```

Check the installed licence before a run:

```bash
flowrs license status
```

Adding a licence may require network access. Once installed, protected-package runs can work
offline until the licence expires. Keep `~/.flowrs` available on containers and cluster nodes;
deleting it means installing the licence again.

If validation fails, use the reported path and expiry information to correct the licence, or ask
the issuer for a replacement. A licence failure for a protected package is exit code `77`; a
missing grant is exit code `79`.

## Run a pipeline

The basic invocation is:

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>]
```

`<PIPELINE>` may be a registered name, a pipeline directory, or a `.flowpkg`. The input directory
must already exist; the work directory is created after validation if absent.
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
