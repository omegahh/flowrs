# Pipeline author guide

This guide is for the person who writes a pipeline: the manifest, step scripts, hooks, and package
that another operator will run.

## Start with a scaffold

Create a working tree and inspect the generated manifest:

```bash
flowrs create demo -d "My first pipeline"
flowrs inspect demo --check-environment
```

The tree contains the files you own and the standard library supplied by FlowRs:

```text
demo/
├── manifest.toml       # pipeline definition
├── steps/               # step scripts named by the manifest
├── hooks/               # optional lifecycle scripts
├── bin/                 # helper executables and detectors
├── lib/                 # libraries used by steps
├── sources/             # optional C/C++ sources
├── Makefile             # optional build for compiled steps
└── stdlib/              # FlowRs runtime contract and language helpers
```

Keep `manifest.toml`, `steps/`, `hooks/`, `bin/`, `lib/`, and any build sources under version
control. `flowrs create --update` refreshes the supplied standard library files.

The smallest useful manifest declares a pipeline, a step, and optional parameters:

```toml
[pipeline]
name = "demo"
version = "0.1.0"

[steps.hello]
exec = "hello.sh"
label = "Hello world"

[params.message]
type = "string"
default = "Hello from demo!"
```

Write each step as an ordinary executable. The [runtime contract](runtime-contract.md) describes
its environment, paths, and logs; the [stdlib](stdlib.md) describes the shared helpers for Bash,
Python, R, and C++.

## Build the pipeline

Use the author reference in this order:

1. [Manifest reference](manifest-reference.md) — fields, defaults, profiles, collections, errors,
   hooks, constraints, and validation rules.
2. [Dependencies and parallelism](dependencies.md) — DAGs, trigger rules, thread budgets,
   scatter/gather, and teardown.
3. [Running](running.md) — the operator flags your pipeline must support, including resume and
   caching.
4. [Distributing](distributing.md) — validation, plaintext or protected packages, grants, signing,
   and registry entries.

Before handing a pipeline to an operator, validate it without creating a package:

```bash
flowrs compile demo
```

Create a package when the pipeline is ready to distribute:

```bash
flowrs compile demo -o demo.flowpkg
```

The [exit-code reference](exit-codes.md) documents the stable codes and machine-readable
diagnostics that wrappers and workflow systems should consume.
