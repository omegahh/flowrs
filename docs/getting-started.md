# Operator guide

This guide is for the person who installs FlowRs, receives a licence, runs a pipeline, and checks
the result. Pipeline authors should start with the [pipeline author guide](authoring.md).

## Install

FlowRs ships as one static binary. Download the archive for your platform from the
[releases page](https://github.com/omegahh/flowrs/releases), unpack it, and put the binary on your
`PATH`:

```bash
tar xzf flowrs-*.tar.gz
sudo install -m755 flowrs /usr/local/bin/flowrs
flowrs --version
```

Shell completions are in the archive under `completions/`. To build from source,
`cargo build --release` writes `target/release/flowrs`.

## Install a licence

**Nothing runs without a valid licence.** A plain pipeline or an unencrypted `.flowpkg` needs the
licence itself. An encrypted `.flowpkg` also needs a grant for that package.

FlowRs searches these paths in order and uses the first file that validates:

1. `./flowrs.license`
2. `./license.json`
3. `/etc/flowrs/license.json`
4. `~/.flowrs/license.json`

Ask the licence issuer which machine identity to send:

```bash
flowrs license fingerprint
```

A machine identity can change after a hardware replacement or operating-system reinstall. When it
does, ask the issuer to reissue the licence.

Install the file they return:

```bash
flowrs license add ./your-licence-file
```

Check the installed licence before a run:

```bash
flowrs license status
```

Adding a licence may require network access. Once installed, runs can work offline until the
licence expires. Keep `~/.flowrs` available on containers and cluster nodes; deleting it means
installing the licence again.

If validation fails, use the reported path and expiry information to correct the licence, or ask
the issuer for a replacement. A licence failure is exit code `77`; a missing grant for an
encrypted package is exit code `79`.

## Run a pipeline

The basic invocation is:

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>]
```

`<PIPELINE>` may be a registered name, a pipeline directory, or a `.flowpkg`. The input directory
must already exist; the work directory is created after the licence gate if absent.
Use `-t` when several runs share one work directory; each task gets its own output directory.

For parameters and run controls, see [Running](running.md). For a pipeline directory, a useful
preflight is:

```bash
flowrs inspect <PIPELINE> --check-environment
```

## Read the result

Each run writes its result under the work directory:

```text
<work>/<task>/status.json   # machine-readable run and step results
<work>/<task>/params.json   # resolved parameter values
<work>/<task>/logs/          # one complete log per execution unit
<work>/<task>/tmp/           # scratch retained after failures
```

`status.json` is the file for automation. Its `schema_version` identifies the document format;
optional fields are absent when they do not apply. The top-level `status` is `running`,
`completed`, or `failed`. Each step records its status, timing, exit code when it ran, and any
failure or skip reason. Scattered steps also record their item results.

The `version_fingerprint` and `input_fingerprint` fields let `--resume` decide whether an earlier
run can be continued. Treat a refusal as a request to start a fresh run unless you have reviewed
the change and deliberately use `--force`.

Console output is a summary. The files under `logs/` contain the complete stdout and stderr for
each step, detector, hook, and scattered item. Use those logs for diagnosis, and
[exit codes](exit-codes.md) for scripts that need to classify failures.

## Manage runs

- Use `--resume` to continue a prior run and reuse completed work. A changed pipeline or input set
  normally requires a fresh task.
- Use `cache = true` in the manifest to reuse declared step outputs across runs. The cache is
  described in [Running](running.md#caching).
- Use the registry commands to give packages stable names:
  `flowrs registry add demo.flowpkg --name demo`, `flowrs registry list`, and
  `flowrs registry remove demo`. A registered package can then be passed to `flowrs run` by name.
- Use `--keep-tmp` after a failure when you need the scratch directory for investigation.

Pipeline authors should continue with the [pipeline author guide](authoring.md), then the
[manifest reference](manifest-reference.md).
