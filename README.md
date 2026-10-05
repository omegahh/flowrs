# FlowRs

[![FlowRs version](https://img.shields.io/github/v/release/omegahh/flowrs?color=58bd9f&style=popout)](https://github.com/omegahh/flowrs/releases/latest)
[![Skills included](https://img.shields.io/badge/skills-included-8b5cf6?style=popout)](https://github.com/omegahh/flowrs/tree/main/skills/flowrs-author)
[![Agent friendly](https://img.shields.io/badge/agents-friendly-3b82f6?style=popout)](https://github.com/omegahh/flowrs/blob/main/docs/exit-codes.md#machine-readable-diagnostics)
[![HPC shared filesystems](https://img.shields.io/badge/HPC-shared%20filesystems-0891b2?style=popout)](https://github.com/omegahh/flowrs/blob/main/docs/running.md#sharing-one-cache-directory)

**A workflow engine for reproducible computational pipelines.**

FlowRs runs directed acyclic graphs declared in TOML manifests. Independent steps run in parallel
within one thread budget, while parameter resolution, scatter/gather, caching, resume, lifecycle
hooks, and machine-readable run records handle the parts around the scripts. A scaffold includes
helpers for Bash, Python, R, and C++.

## Install

Release archives contain a statically linked Linux x86_64 binary, shell completions, the authoring
skill, and this guide. No Rust toolchain is needed to run a release build.

```bash
curl -LO https://github.com/omegahh/flowrs/releases/latest/download/flowrs-linux-x86_64.tar.gz
curl -LO https://github.com/omegahh/flowrs/releases/latest/download/flowrs-linux-x86_64.tar.gz.sha256
sha256sum -c flowrs-linux-x86_64.tar.gz.sha256
tar xzf flowrs-linux-x86_64.tar.gz
sudo install -m755 flowrs /usr/local/bin/flowrs
flowrs --version
```

The archive layout is:

```text
flowrs                 # CLI executable
README.md              # this guide
completions/           # bash, zsh, and fish
skills/                # FlowRs authoring skill and references
```

### Shell completions

```bash
# Bash
sudo install -m644 completions/flowrs.bash /etc/bash_completion.d/flowrs

# Zsh
mkdir -p ~/.zsh/completion
cp completions/_flowrs ~/.zsh/completion/
# Add ~/.zsh/completion to fpath in ~/.zshrc.

# Fish
mkdir -p ~/.config/fish/completions
cp completions/flowrs.fish ~/.config/fish/completions/
```

## Quick start

Create a scaffold, validate it, and run it over an input directory:

```bash
flowrs create hello
flowrs compile ./hello --json
mkdir -p input work
flowrs run ./hello -i ./input -w ./work -t first
```

The scaffold contains a `manifest.toml`, step scripts, optional hook and detector directories, a
bundled standard library, and a working example. `flowrs inspect` shows the graph and resolved
manifest shape without running steps:

```bash
flowrs inspect ./hello
flowrs inspect ./hello --check-environment
flowrs inspect ./hello --json
```

## Define a pipeline

A pipeline is a directory whose manifest names ordinary executable scripts:

```text
hello/
├── manifest.toml
├── steps/
│   └── greet.sh
├── hooks/                 # optional lifecycle hooks
├── bin/                   # optional detectors and helper executables
└── stdlib/                # supplied by `flowrs create`
```

This manifest declares one step, one output, and one parameter:

```toml
[pipeline]
name = "hello"
version = "0.1.0"

[steps.greet]
exec = "greet.sh"
label = "Write greeting"
outputs = ["${OUT_DIR}/hello.txt"]

[params.message]
type = "string"
default = "Hello from FlowRs"
```

`steps/greet.sh` can use the bundled Bash helpers:

```bash
#!/usr/bin/env bash
set -euo pipefail

log_info "Writing greeting"
printf '%s\n' "$(get_config message)" > "${OUT_DIR}/hello.txt"
```

Steps connect with `depends_on`. A step that has no dependency can start as soon as the run is
ready; independent branches share the run's thread budget. Parameters can come from the manifest,
a profile or detector, a config file, or repeated `-p KEY=VALUE` overrides. See the
[manifest reference](https://github.com/omegahh/flowrs/blob/main/docs/manifest-reference.md) for all fields, validation rules, collections,
hooks, and constraints.

## Validate and package

Validate a pipeline before running it:

```bash
flowrs compile ./hello
```

Use `--json` when a tool needs a stable diagnostics envelope:

```bash
flowrs compile ./hello --json
```

Create a distributable package with `-o`:

```bash
flowrs compile ./hello -o hello.flowpkg
flowrs compile ./hello -o hello-protected.flowpkg --encrypt
```

A plaintext pipeline directory and a plain package run without a licence. A protected package
requires a valid licence and a matching grant for that package. The [distribution guide](https://github.com/omegahh/flowrs/blob/main/docs/distributing.md)
covers signing, protection, grants, and registry entries.

## Run and inspect results

The basic run command is:

```bash
flowrs run <PIPELINE> -i <INPUT_DIR> -w <WORK_DIR> [-t <TASK_ID>]
```

`<PIPELINE>` can be a directory, a `.flowpkg`, or a name registered with `flowrs registry add`.
Useful run options include:

```text
-p, --param KEY=VALUE       Override one parameter (repeatable)
-c, --config FILE           Read JSON, TOML, or KEY=VALUE parameters
-@, --threads N             Set the run's total thread budget
--max-in-flight N           Bound items of one scattered step
-s, --start-step STEP       Start at a step and drop its upstream
-e, --end-step STEP         Stop at a step and drop its downstream
-k, --skip-steps STEP ...   Skip named steps
--resume                    Continue a prior run
--force                     Allow a safe-to-resume parameter override
--keep-tmp                  Keep temporary files after a clean run
```

Each run records its result under the work directory (or under `WORK_DIR/TASK_ID/` when `-t` is
used):

```text
status.json    # machine-readable run and step results
params.json    # resolved parameter values
logs/          # logs for steps, detectors, hooks, and scattered items
tmp/           # scratch files; removed after success unless --keep-tmp
```

Read `status.json` for automation. It includes the schema version, run status, step outcomes,
exit codes, timings, and scattered item results. The [running guide](https://github.com/omegahh/flowrs/blob/main/docs/running.md) explains
slices, resume, caching, signals, and in-flight limits.

## Registry

Register a pipeline or package for name-based execution:

```bash
flowrs registry add ./hello --name hello
flowrs run hello -i ./input -w ./work
flowrs registry list --detailed
flowrs registry list --json
flowrs registry remove hello
```

## Licence

Only protected packages require a machine-bound licence. Ask the licence issuer which machine
identity to send:

```bash
flowrs license fingerprint
flowrs license add ./flowrs.license
flowrs license status
```

FlowRs searches `./flowrs.license`, `./license.json`, `/etc/flowrs/license.json`, and
`~/.flowrs/license.json`, in that order. A licence is checked when a protected package is opened;
that package additionally needs a matching pipeline grant.

## Exit codes

The process code is intended for scripts:

| Code | Meaning |
| ---: | ------- |
| `1-63` | Pipeline-declared error codes, passed through from a step |
| `64` | Invalid command or supplied value |
| `65` | Malformed or corrupt input/package |
| `70` | Runtime or internal failure |
| `77` | Protected package licence is missing, invalid, expired, or for another machine |
| `78` | Manifest configuration is invalid |
| `79` | Licence is valid but lacks a grant for a protected package |

For a run, `status.json` identifies the step and its exit code. See the complete
[exit-code reference](https://github.com/omegahh/flowrs/blob/main/docs/exit-codes.md) for diagnostics and built-in step errors.

## Documentation and authoring support

- [Getting started](https://github.com/omegahh/flowrs/blob/main/docs/getting-started.md) - install, licence, run, and read results
- [Pipeline author guide](https://github.com/omegahh/flowrs/blob/main/docs/authoring.md) - build and package a pipeline
- [Manifest reference](https://github.com/omegahh/flowrs/blob/main/docs/manifest-reference.md) - every manifest field and rule
- [Runtime contract](https://github.com/omegahh/flowrs/blob/main/docs/runtime-contract.md) - environment variables, paths, and logs
- [Standard library](https://github.com/omegahh/flowrs/blob/main/docs/stdlib.md) - Bash, Python, R, and C++ helpers
- [Dependencies and parallelism](https://github.com/omegahh/flowrs/blob/main/docs/dependencies.md) - DAGs, trigger rules, and scatter/gather
- [Running](https://github.com/omegahh/flowrs/blob/main/docs/running.md) - slices, resume, caching, and signals
- [Distributing](https://github.com/omegahh/flowrs/blob/main/docs/distributing.md) - `.flowpkg`, signing, protection, and grants
- [Exit codes](https://github.com/omegahh/flowrs/blob/main/docs/exit-codes.md) - stable codes and machine-readable diagnostics

The public repository keeps the generated [manifest schema](https://github.com/omegahh/flowrs/blob/main/schema/manifest-v1.json),
[completions](https://github.com/omegahh/flowrs/tree/main/completions), [documentation](https://github.com/omegahh/flowrs/tree/main/docs), and [FlowRs authoring skill](https://github.com/omegahh/flowrs/tree/main/skills)
alongside this README. Editors can use the schema directly from
`https://raw.githubusercontent.com/omegahh/flowrs/main/schema/manifest-v1.json`.

Questions and bug reports belong in [GitHub Issues](https://github.com/omegahh/flowrs/issues).
