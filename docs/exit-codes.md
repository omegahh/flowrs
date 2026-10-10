# Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Run succeeded; executed successful steps passed declared-output checks |
| `1-63` | Author-declared errors; failing step codes pass through |
| `64` | Invalid invocation or supplied parameter |
| `65` | Malformed or corrupt input/package |
| `70` | Runtime or internal failure |
| `77` | Protected-package licence is unusable |
| `78` | Invalid manifest |
| `79` | Valid licence lacks a usable grant for this protected build |
| `120` | `MISSING_OUTPUT`: a step exited 0 without a declared output |
| `121` | `CACHE_INPUT_CHANGED`: conflicting shared-cache replacement detected |
| `124` | `TIMEOUT` |
| `126` / `127` | Not executable / command not found |
| `128+N` | Signal termination or run cancellation |

CLI argument-parser errors can exit 2. Skipped or filtered steps do not receive fresh output
checks, so run success does not prove their outputs exist.

For protected packages, fix 77 by installing a valid licence. Fix 79 by requesting a matching
grant from the issuer. Pipeline directories and plain packages do not consult licences.

Failing step codes pass through verbatim, including codes outside the author band. An undeclared
step exit 77 can therefore resemble a licence failure. Read `status.json` to identify the failing
step and its code.

## Built-in input-health codes

These names can be passed to `die` without an `[[errors]]` declaration.

| Code | Name | Meaning |
| --- | --- | --- |
| 100 | `NOT_GZIP` | Not gzip-compressed |
| 101 | `DOUBLE_GZIPPED` | Compressed twice |
| 102 | `UTF8_BOM` | UTF-8 byte-order mark |
| 103 | `UTF16_ENCODING` | UTF-16 input |
| 104 | `CRLF_LINE_ENDINGS` | Reserved; health helpers do not emit it |
| 105 | `BINARY_CONTENT` | Null bytes in text |
| 106 | `BAD_FASTQ_SHAPE` | Invalid FASTQ shape |
| 107 | `BAD_FASTA_SHAPE` | Invalid FASTA shape |
| 108 | `UNREADABLE` | Missing or unreadable input |
| 109 | `INCOMPLETE_GZIP` | Truncated gzip encountered during a depth check |

See [Stdlib](stdlib.md#check-input-health) for checks and their inspection limits.

## Machine-readable diagnostics

Use `flowrs compile DIR --json` for a diagnostic envelope on stdout:

```json
{
  "ok": false,
  "exit_code": 78,
  "diagnostics": [
    {
      "code": "unknown_dependency",
      "field": "steps.analyze.depends_on",
      "ref": "prepare",
      "fatal": true,
      "message": "Dependency is not declared"
    }
  ]
}
```

Compile success is `{"ok":true,"exit_code":0,"diagnostics":[]}`.
`inspect --json` instead returns the manifest projection on success and the envelope on failure.
Human progress goes to stderr. Run has no `--json`; consume `status.json`.
Argument-parser errors can exit 2 with usage on stderr and no JSON document.

| Field | Contract |
| --- | --- |
| `ok`, `exit_code`, `diagnostics` | Envelope fields; exit_code matches the process result |
| `code` | Stable diagnostic identifier |
| `field` | Stable dotted manifest path when present |
| `fatal` | Present as true when dependent checks could not run |
| `ref`, `line` | Advisory offending value and one-based parse-error line |
| `message`, `hint` | Advisory prose; do not parse or match wording |

Validation can report multiple findings. A parse failure reports one; a fatal finding can hide
dependent findings. Fix the reported problems and validate again.

## Diagnostic codes

<!-- BEGIN DIAGNOSTIC CODES -->
**Whole-manifest and syntax**

| Code | Raised when |
| --- | --- |
| `manifest_syntax` | The file is not valid TOML, or does not deserialize into the manifest schema. |
| `manifest_unreadable` | The manifest file could not be read, or is absent from the pipeline directory. |
| `no_steps` | The manifest declares no `[steps]` at all. |

**Steps**

| Code | Raised when |
| --- | --- |
| `invalid_step_name` | A step name is empty, or contains a path separator or `..`. |
| `invalid_step_exec` | A step's `exec` is empty, or contains a path separator or `..`. |
| `unknown_dependency` | A `depends_on` entry names a step that is not declared. |
| `teardown_dependency` | A non-teardown step depends on a teardown step. |
| `cycle_detected` | A cycle exists in the `depends_on` graph. |
| `retry_limit_exceeded` | A retry count exceeds the maximum, on a step, in `[defaults]`, or on an `[[errors]]` entry. |
| `invalid_threads_weight` | A step's `threads_weight` is 0. |
| `threads_weight_on_fixed` | A step declares `threads_weight` alongside a fixed `threads = <int>`. |
| `invalid_output_path` | An `outputs` path is empty, has traversal components, uses an invalid variable root, or does not match the step's scalar/item scope. |
| `output_in_input_dir` | An `outputs` path uses `${INPUT_DIR}`, which scripts must not modify. |

**Collections and scatter**

| Code | Raised when |
| --- | --- |
| `invalid_collection_source` | A `[collections.<name>] source` is empty or uses variables other than a leading `${INPUT_DIR}`. |
| `invalid_collection_name` | A collection name is empty, or contains a path separator or `..`. |
| `invalid_collection_id_column` | A `[collections.<name>] id_column` is empty. |
| `unknown_collection` | A `scatter` names a collection the manifest does not declare. |
| `unknown_gathered_step` | A `gather` entry names a step that is not declared. |
| `gather_of_unscattered_step` | A `gather` entry names a step that does not scatter. |
| `scatter_with_gather` | A step declares both `scatter` and `gather`. |
| `scatter_incompatible_step` | A step is both `teardown` and scattered. |
| `item_output_collision` | Two steps over one collection declare the same `${ITEM_DIR}` output. |
| `scattered_upstream_needs_gather` | A scalar step depends on a scattered one without gathering it. |
| `cross_collection_dependency` | Two steps over different collections depend on each other, which is a Cartesian product. |

**Parameters**

| Code | Raised when |
| --- | --- |
| `reserved_param_name` | A param name collides with an engine, system, or language environment variable. |
| `param_name_collision` | Two param declarations differ only in case, so they name one parameter. |
| `unknown_param_group` | A param's `group` names a group that is not declared in `[groups]`. |
| `invalid_param_increment` | A parameter increment is non-positive, non-finite, or used with a non-numeric type. |
| `unknown_param_field` | A key inside a `[params.<name>]` table is a scalar where a profile-override table was expected. |
| `invalid_profile_override` | A `[params.<name>.<profile>]` table does not have the shape of a profile override. |
| `removed_const_field` | The unsupported const field was used; declare readonly and a default. |
| `bounds_violation` | A value is outside the `min`/`max`/`exclusive_min`/`exclusive_max` in force. |
| `unsatisfiable_bounds` | The bounds in force admit no value at all, e.g. `min = 100` with `max = 10`. |
| `enum_violation` | A value is not in the param's `enum`. |
| `enum_type_mismatch` | An enum entry cannot be coerced to the parameter's declared type. |
| `param_type_mismatch` | A value is not of the param's declared `type`, and cannot be coerced to it. |
| `unknown_param` | `-p` or `-c` names a param the manifest does not declare. |
| `missing_required_param` | No supplied, resumed, detected, profile-default, or base-default value resolves a declared parameter. |
| `readonly_override` | `-p` or `-c` tries to override a `readonly` param. |
| `readonly_without_default` | A readonly parameter lacks a default in a reachable profile or base configuration. |

**Constraints**

| Code | Raised when |
| --- | --- |
| `invalid_constraint_expr` | A `[[constraints]]` expression is not a single supported comparison. |
| `constraint_op_unsupported` | A constraint's operator is not supported for the operand's type. |
| `constraint_unknown_param` | A constraint references a param that is not declared. |
| `constraint_param_unresolvable` | A referenced parameter lacks a default in a reachable profile or base configuration. |
| `constraint_failed` | A constraint's `when` held and its `require` did not. |

**Detection**

| Code | Raised when |
| --- | --- |
| `invalid_detector` | A `detector` is empty, contains a path separator, or contains `..`. |
| `missing_detector_script` | A declared `detector` is not present under `bin/`. |
| `detector_readonly` | A parameter combines detector and readonly. |
| `detector_in_profile_override` | A detector is declared inside a profile override, where detectors are unsupported. |
| `runner_name_collision` | Runner names share a log path or gather manifest, a scattered step uses the detector log namespace, or a scalar log file conflicts with a scattered log directory. |

**Profiles**

| Code | Raised when |
| --- | --- |
| `multiple_profiled_params` | More than one parameter declares profiles. |
| `profiles_without_domain` | A non-boolean profiled param has no `enum` declaring the values its profiles must partition. |
| `profile_empty` | A profile's member list is empty. |
| `profile_value_not_in_enum` | A profile member is outside the selector's domain. |
| `profile_value_duplicated` | A value is listed more than once within or across profiles. |
| `profile_value_unassigned` | A value the profiled param can take belongs to no profile. The categories must partition its whole domain, so a run could otherwise resolve no category at all. |
| `unknown_profile_override` | A profile override names an undeclared profile. |
| `profile_override_on_profiled_param` | The profile selector has a profile override of its own. |
| `profile_override_on_detected_param` | A parameter combines a detector with a profile override. |

**Errors and hooks**

| Code | Raised when |
| --- | --- |
| `invalid_error_charset` | An `[[errors]]` code uses a character outside `A-Z`, `0-9`, `_`, or is empty. |
| `duplicate_error_code` | Two `[[errors]]` entries declare the same `code`. |
| `reserved_error_code` | An `[[errors]]` code reuses an engine built-in name. |
| `exit_code_out_of_range` | An `[[errors]]` `exit_code` is outside the author band. |
| `duplicate_exit_code` | Two `[[errors]]` entries claim the same `exit_code`. |
| `unknown_hook_error_code` | A `[pipeline.hooks.on_error]` key is neither a declared `[[errors]]` code nor a built-in. |
| `invalid_hook_script` | A hook script name is empty, is an absolute path, or contains a path separator or `..`. |

**Cache**

| Code | Raised when |
| --- | --- |
| `cache_dir_missing` | A step sets `cache = true` but the pipeline declares no `[pipeline] cache_dir`. |
| `invalid_cache_dir` | `[pipeline] cache_dir` is empty, is not a single relative segment, or is a name FlowRs owns inside a run directory. |
| `cache_incompatible_step` | A cached step is teardown or uses a trigger rule other than all_success. |
| `cache_key_unknown_param` | A `cache_key` entry names a param that is not declared. |
| `cache_key_readonly_param` | A cache key names a readonly parameter. |
| `cache_output_collision` | Two cached steps declare the same `${CACHE_DIR}` filename as an output. |
| `uncached_cache_writer` | A step declares an `outputs` path under `${CACHE_DIR}` without setting `cache = true`. |
| `removed_cache_dir_variable` | An output uses the unsupported CACHE_DIR_<STEP> variable form. |

**Invocation**

| Code | Raised when |
| --- | --- |
| `config_unreadable` | A `-c` config file could not be read, or its JSON/TOML/KEY=VALUE content did not parse. |
| `invalid_param_override` | A `-p` override is not `KEY=VALUE`, or its key is empty. |
| `missing_step_executable` | Packaging was requested but a step's `exec` file does not exist under `steps/`. |
| `environment_check_failed` | `inspect --check-environment` found a required tool, package, or shared library missing. One diagnostic per missing item. |
<!-- END DIAGNOSTIC CODES -->
