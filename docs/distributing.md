# Share a pipeline

FlowRs pipelines can be shared as source directories or as `.flowpkg` files. Validate a source
tree before handing it to another runner:

```bash
flowrs compile demo
flowrs inspect demo --check-environment
```

If the directory has a Makefile, `compile` runs `make clean`, then `make`, before validation.
Provide a clean target that removes compiled outputs. Missing step or detector files are fatal;
missing hooks remain warnings.

Keep the manifest, `steps/` tree, helper files, detectors, hooks, standard library, and any build
sources together. Step executables must be at the paths declared by the manifest, relative to
`steps/`. `bin/` holds detectors and helper executables; `lib/` holds shared scripts, native
libraries, and supporting assets; `hooks/` holds lifecycle scripts and small helpers; and `stdlib/`
is supplied by FlowRs. Large reference datasets such as genome indexes and search databases are
typically managed externally and passed by path parameter.

Create a packaged pipeline (a plaintext `.flowpkg`) from a validated source tree:

```bash
flowrs compile demo -o demo.flowpkg
```

Package documents, including the manifest, must each fit within 1 MiB. An extracted package tree
is limited to 1 GiB of expanded TAR data and 10,000 archive entries across all its payloads.
These limits also apply when inspecting a package. Keep large datasets outside the package and
pass their paths as parameters.

A runner can pass that file directly to `flowrs run`, or register it for name-based execution:

```bash
flowrs run demo.flowpkg -i input -w work
flowrs registry add demo.flowpkg --name demo
flowrs run demo -i input -w work -t run001
```

Protected releases require access configured by their publisher. If FlowRs reports an access problem or
cannot open a package, send the publisher the exact error and package version. Do not modify the
package to work around the failure.

`flowrs registry list --detailed` shows stored paths and whether they exist; `--json` emits the
list as JSON. The `Type` column and JSON `type` field use these pipeline states:

| State | Source |
| --- | --- |
| `plaintext` | A pipeline directory |
| `packaged` | A plaintext `.flowpkg` file |
| `protected` | A publisher-provided `.flowpkg` release requiring authorization |

Removing a registration removes its name. Use the original pipeline path to run it without
registration.
