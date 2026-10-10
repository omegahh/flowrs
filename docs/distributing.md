# Distributing a pipeline

## Validate, then package

Validate a pipeline directory without writing a package:

```bash
flowrs compile demo
```

If the directory has a Makefile, compile runs `make clean`, then `make`, before validation.
Provide a clean target that removes compiled outputs. A build failure stops compilation.
Missing step, detector, or hook files produce warnings when validating without a package;
resolve those before distributing.

Create a plain package:

```bash
flowrs compile demo -o demo.flowpkg
```

Packaging requires step and detector executables; missing hooks remain warnings.
A plain `.flowpkg` has readable contents and needs no licence or grant to run.

## Protected packages

Protect the source payloads with encryption:

```bash
flowrs compile demo -o demo-protected.flowpkg --encrypt
```

Running this package needs a valid licence and a matching grant for its source
content. If the licence lists machines, this machine must be included; an empty list allows
any machine. A valid licence without the grant is insufficient. See
[licence installation](getting-started.md#install-a-licence-for-protected-packages).

Use `--sign-with private_key.pem` when packaging to add a signature verified against FlowRs'
embedded trust key. Signing with an unrelated key does not establish trust for recipients.

## Request a grant

Send the protected package and the requested machine identity to your group's licence issuer.
The issuer can include the package grant when generating a licence:

```bash
license-gen generate -p private_key.pem -l "Field Test" -d 30 \
  --machine <fingerprint> --grant demo-protected.flowpkg -o flowrs.license
```

The grant covers that named source build. Editing bundled content, including the manifest,
scripts, libraries, or stdlib, requires a grant matching the new package.
A hardware replacement or operating-system reinstall can change machine identity and require
reissue of a machine-restricted licence.

## Register a name

```bash
flowrs registry add demo.flowpkg --name demo
flowrs registry list
flowrs run demo -i input -w work -t run001
```

Package registration copies the package into managed storage. Directory registration keeps a
reference to the directory, so edits there affect later runs.

The list shows name, version, type, and file. For protected packages, the authorization marker
indicates whether this machine has a valid licence and matching grant.
Use `flowrs license status` for licence details.

```bash
flowrs registry list --detailed
flowrs registry list --json
flowrs registry remove demo
```

Removing a registration removes the name. Use the original pipeline path to run it without
registration.
