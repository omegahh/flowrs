# FlowRs Manifest Schema

This directory contains the JSON Schema for FlowRs `manifest.toml` files.

## Files

- `manifest-v1.json` — JSON Schema for the current manifest format

## Using the Schema

### Editor Validation

Many editors support JSON Schema validation for TOML files via plugins:

**VS Code** (with [Even Better TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml)):

Use a schema association relative to your manifest's location, for example:
```toml
#:schema ../schema/manifest-v1.json
```

Or configure in `.vscode/settings.json`:
```json
{
  "evenBetterToml.schema.associations": {
    "manifest.toml": "schema/manifest-v1.json"
  }
}
```

### Programmatic Validation

```bash
# Convert TOML to JSON, then validate with any JSON Schema validator
toml2json manifest.toml | jsonschema schema/manifest-v1.json
```

## Maintenance

The schema is **generated** from Rust types in `src/manifest/` and **committed** to version control.
The generator writes both `schema/manifest-v1.json` and the self-contained copy at
`skills/flowrs-author/assets/manifest-v1.json`.

To regenerate after changing manifest types:

```bash
cargo run --bin generate-schema --features schema
git add schema/manifest-v1.json skills/flowrs-author/assets/manifest-v1.json
```

CI will fail if either committed copy is out of sync with the source types.

## Limitations

The schema describes field names and value shapes, including both scatter spellings, parameter
defaults, enum lists, profile membership, and `[params.NAME.PROFILE]` override tables. Parameter
literals are strings, numbers, or booleans; JSON numbers include integer values.

Run `flowrs compile PIPELINE --json` for semantic validation. Schema validation alone does not
check that literals match a parameter's declared type, bounds, increment, or enum; that profiles
partition its domain; that references resolve and the graph is acyclic; or that error codes and
retry counts obey the engine's rules. Collection-file contents and supplied run-time values are
checked when running the pipeline.
