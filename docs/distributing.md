## Distributing

### Validate, then package

Without `-o`, `compile` builds and validates in place without writing a package. If a `Makefile`
exists, it runs before validation and may create build outputs. Missing step, detector, or hook
scripts produce warnings at this stage, so check those even when validation succeeds:

```console
$ flowrs compile full
  success Manifest valid: full v0.2.0 (7 steps, 3 params)
  success All 7 step executables present
```

With `-o`, it also bundles the pipeline into one immutable `.flowpkg`. Missing step or detector
executables are fatal when packaging; missing hooks remain warnings:

```console
$ flowrs compile full -o full.flowpkg
     info Running make to compile C++ steps...
  success C++ steps compiled successfully
  success Manifest valid: full v0.2.0 (7 steps, 3 params)
  success All 7 step executables present
     info Packaging: /tmp/full -> full.flowpkg
     info Including: steps, bin, hooks, lib, stdlib
     info Stdlib: v0.5.0 (8 files)
  success Created package: full.flowpkg
     info Package is unencrypted: it runs without a per-package grant (base license still
     required) and its contents are readable.
```

A plain package runs for anyone holding a valid licence — no grant needed — and its contents are
readable. Use it when the code is not the secret.

### Plain vs `--encrypt`

`--encrypt` encrypts the payloads. Running the result then needs a **grant for that source
content**:

```console
$ flowrs compile full -o full-enc.flowpkg --encrypt
  success Created package: full-enc.flowpkg
     info Payloads are encrypted: running this package requires a license grant.

$ flowrs run full-enc.flowpkg -i input -w work9 -t enc
     info Checking license...
  success License valid (licensee: Field Test)
    error License verification failed: License has no grant for pipeline 'full'
    (requested by package)
```

Note what that shows: the licence is valid, and it is still refused. Tier 1 admitted the engine;
tier 2 is missing.

`--sign-with <KEY>` adds a signature so a recipient can verify the package came from you.

### Request a grant for an encrypted package

A grant authorizes one named package build for the machines and dates chosen by the issuer. Send
the package and the machine identity requested by the issuer to whoever issues licences for your
group.

```console
$ license-gen generate -p private_key.pem -l "Field Test" -d 30 \
    --machine <fingerprint> --grant full-enc.flowpkg -o flowrs.license
  Authorized machines: 1
  Schema version: 2.0
  Pipeline grants:
    full v0.2.0
```

With that licence in place, the encrypted package runs:

```console
$ flowrs run full-enc.flowpkg -i input -w work9 -t enc
  success Pipeline completed: 6 steps completed, 1 skipped in 1s
```

Treat the packaged build as the artifact covered by the grant. If you edit the manifest or any
bundled step, hook, executable, library, or standard-library file, request a fresh grant for the
new package. A machine identity change, such as replacing hardware or reinstalling the operating
system, requires a reissued licence.

### Register for named use

Registering copies a package into FlowRs' managed store and gives it a name, so runs stop naming
paths:

```console
$ flowrs registry add full.flowpkg --name fullpkg
  success Registered 'fullpkg' -> /home/you/.flowrs/store/51139f37….flowpkg
    (copied from /tmp/full.flowpkg)

$ flowrs registry list
Registered pipelines:

  fullpkg              51139f37….flowpkg
  simple               /home/you/pipelines/simple

$ flowrs run fullpkg -i input -w work -t task001
```

A directory can be registered too, in which case the registry records the path rather than copying.
`registry list --json` is machine-readable and `registry remove <NAME>` removes an entry. The
registry is a TOML file at `~/.flowrs/registry.toml`, file-locked against concurrent writes.

---

## Where to look next

- **`stdlib/CONTRACT.md`**, in every scaffolded pipeline — the authoritative runtime contract
- **`schema/manifest-v1.json`** — generated from the Rust types; point your editor at it
- **`flowrs inspect <pipeline>`** — how FlowRs actually read your manifest
- **`flowrs <command> --help`** — every flag, with the reasoning behind the odd ones
