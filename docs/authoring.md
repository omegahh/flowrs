# Pipeline author guide

This guide is for the person who writes a pipeline: the manifest, step scripts, and hooks that
another runner will use.

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
├── hooks/               # optional lifecycle scripts and small helpers
├── bin/                 # author-developed detectors and helper executables
├── lib/                 # shared scripts, native libraries, and supporting assets
├── sources/             # optional C/C++ sources
├── Makefile             # optional build for compiled steps
└── stdlib/              # FlowRs runtime contract and language helpers
```

Pipelines usually contain executable logic and supporting assets. Large reference datasets, such as
genome indexes and search databases, are typically managed externally and supplied through path
parameters. Authors can include library assets in `lib/`; `stdlib/` is supplied by FlowRs.

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
4. [Distributing](distributing.md) — validate and share a source tree, or use a supplied package.

Before handing a pipeline to an operator, validate it without creating a package:

```bash
flowrs compile demo
```

To share a source pipeline, provide the complete validated directory. For a portable `.flowpkg`,
give the validated source to the FlowRs release maintainer and request a package for distribution.

The [exit-code reference](exit-codes.md) documents the stable codes and machine-readable
diagnostics that wrappers and workflow systems should consume.
