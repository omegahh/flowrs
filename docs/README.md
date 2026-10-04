# FlowRs documentation

FlowRs runs a directed acyclic graph of ordinary scripts. These pages explain the user-facing
contracts; the agent-facing operating instructions live in `skills/flowrs-author/`.

## Choose a guide

| Audience        | Page                                  | Use it for                                                      |
| --------------- | ------------------------------------- | --------------------------------------------------------------- |
| Operator        | [Operator guide](getting-started.md)  | Install, licence, run a pipeline, read results, and manage runs |
| Pipeline author | [Pipeline author guide](authoring.md) | Create a pipeline and find the complete author reference        |

## Operator reference

| Page                        | Use it for                                                |
| --------------------------- | --------------------------------------------------------- |
| [Running](running.md)       | Slices, resume, caching, in-flight limits, and signals    |
| [Exit codes](exit-codes.md) | Process codes, diagnostic envelopes, and diagnostic codes |

## Pipeline author reference

| Page                                            | Use it for                                                        |
| ----------------------------------------------- | ----------------------------------------------------------------- |
| [Manifest reference](manifest-reference.md)     | Every manifest section, field, and validation rule                |
| [Runtime contract](runtime-contract.md)         | Environment variables, paths, working directory, and logs         |
| [Stdlib](stdlib.md)                             | Bash, Python, R, and C++ helpers and input-health checks          |
| [Dependencies and parallelism](dependencies.md) | DAGs, trigger rules, thread budgets, scatter/gather, teardown     |
| [Distributing](distributing.md)                 | Validation, `.flowpkg` packages, encryption, grants, and registry |

## Related material

- `stdlib/CONTRACT.md` in a scaffolded pipeline is the exact runtime contract shipped with it.
- `schema/manifest-v1.json` is the generated manifest schema for editors and tooling.
- `flowrs <command> --help` is the authoritative CLI surface.
