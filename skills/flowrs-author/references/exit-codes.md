# Exit Codes And Diagnostics

## Process Codes

| Code | Meaning |
| --- | --- |
| 0 | Success and every declared output exists |
| 1–63 | Author-defined [[errors]] codes; passed through |
| 64 | Invalid invocation or value from the invocation |
| 65 | Malformed or corrupt input data or package |
| 70 | Runtime, process, or internal failure |
| 77 | Invalid or unusable base licence |
| 78 | Manifest is invalid |
| 79 | Valid licence lacks a grant for the encrypted package |
| 100–119 | Built-in input-health codes |
| 120 | Declared output missing after exit 0 |
| 124 | Step timeout |
| 126 | Command found but not executable |
| 127 | Command not found |
| 128+N | Process killed by signal N |

The author band is 1 through 63. Keep declared codes there. A step code is passed through
verbatim, so an undeclared step exit 77 is indistinguishable from a licence failure when reading only
the process code. Read status.json to identify the step.

The blame line is:

- 64: fix the command, flag, config, or supplied value.
- 78: fix the manifest.
- 77: install or repair the base licence.
- 79: ask the issuer for a package grant.

## JSON Envelope

compile --json emits JSON on stdout for success and failure. inspect --json emits the manifest
projection on success and the envelope only on failure. Human stderr and the process exit code are
unchanged. run has no --json.

~~~json
{
  "ok": false,
  "exit_code": 78,
  "diagnostics": [
    {
      "code": "unknown_dependency",
      "field": "steps.align.depends_on",
      "ref": "trim",
      "message": "advisory prose",
      "hint": "advisory facts",
      "fatal": true
    }
  ]
}
~~~

Match code, field, and exit_code. Treat message, hint, ref, and line as advisory. field is a dotted
manifest path when one exists. line is a 1-based TOML line when parsing preserved a span. fatal is
present only when true and means later checks may have been skipped; it is absent instead of false.
A successful envelope is {"ok":true,"exit_code":0,"diagnostics":[]}. A failure outside the
diagnostic contract can have an empty diagnostics array.

Validation collects independent structural findings in deterministic order. A TOML parse failure
usually yields one diagnostic because parsing stops before validation.

## Diagnostic Codes

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
| `invalid_output_path` | An `outputs` path is empty, relative without a variable, or uses an undeclared variable. |
| `output_in_input_dir` | An `outputs` path writes into `${INPUT_DIR}`, which is mounted read-only. |

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
| `removed_const_field` | `const` was used. It no longer exists; `readonly = true` with a `default` replaces it. |
| `bounds_violation` | A value is outside the `min`/`max`/`exclusive_min`/`exclusive_max` in force. |
| `unsatisfiable_bounds` | The bounds in force admit no value at all, e.g. `min = 100` with `max = 10`. |
| `enum_violation` | A value is not in the param's `enum`. |
| `enum_type_mismatch` | An `enum` entry is not of the param's declared `type`, so it can never be selected. |
| `param_type_mismatch` | A value is not of the param's declared `type`, and cannot be coerced to it. |
| `unknown_param` | `-p` or `-c` names a param the manifest does not declare. |
| `missing_required_param` | A declared param has no default, no detected value, and no `-p`/`-c` override. |
| `readonly_override` | `-p` or `-c` tries to override a `readonly` param. |
| `readonly_without_default` | A `readonly` param has no default, so nothing can ever give it a value. |

**Constraints**

| Code | Raised when |
| --- | --- |
| `invalid_constraint_expr` | A `[[constraints]]` expression is not a single supported comparison. |
| `constraint_op_unsupported` | A constraint's operator is not supported for the operand's type. |
| `constraint_unknown_param` | A constraint references a param that is not declared. |
| `constraint_param_unresolvable` | A constraint references a param that is not guaranteed to resolve to a value. |
| `constraint_failed` | A constraint's `when` held and its `require` did not. |

**Detection**

| Code | Raised when |
| --- | --- |
| `invalid_detector` | A `detector` is empty, contains a path separator, or contains `..`. |
| `missing_detector_script` | A declared `detector` is not present under `bin/`. |
| `detector_readonly` | A param declares both `detector` and `readonly`: a value a script recomputes each run is not a named constant. |
| `detector_in_profile_override` | A `detector` appears inside `[params.<name>.<profile>]`. Every detector runs before any category is known, so a per-profile one could never apply. |
| `runner_name_collision` | Two runners resolve to one unit name, and so to one log file: two detector scripts, or two scripts in one hook phase, whose names differ only by extension. |

**Profiles**

| Code | Raised when |
| --- | --- |
| `multiple_profiled_params` | More than one param declares `profiles`. A run resolves one category, so a second would make every profile-specific default ambiguous. |
| `profiles_without_domain` | A non-boolean profiled param has no `enum` declaring the values its profiles must partition. |
| `profile_empty` | A declared profile has no member values, so it can never be selected. |
| `profile_value_not_in_enum` | A profile member value is not in the profiled param's `enum`, so it can never be selected. |
| `profile_value_duplicated` | A value is claimed twice — by two profiles, which makes every profile-specific default ambiguous, or twice by one profile. The message says which. |
| `profile_value_unassigned` | A value the profiled param can take belongs to no profile. The categories must partition its whole domain, so a run could otherwise resolve no category at all. |
| `unknown_profile_override` | A `[params.<name>.<profile>]` override names a profile no param declares, so it never applies. |
| `profile_override_on_profiled_param` | The profiled param carries a category-keyed default of its own. It *produces* the category, so the override could never apply. |
| `profile_override_on_detected_param` | A param with a `detector` carries a category-keyed default. Detection outranks every declared default, so the override could never win. |

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
| `cache_incompatible_step` | A step combines `cache = true` with a key that makes its result unreusable. |
| `cache_key_unknown_param` | A `cache_key` entry names a param that is not declared. |
| `cache_key_readonly_param` | A `cache_key` entry names a `readonly` param, whose change the resume drift gate cannot see. |
| `cache_output_collision` | Two cached steps declare the same `${CACHE_DIR}` filename as an output. |
| `uncached_cache_writer` | A step declares an `outputs` path under `${CACHE_DIR}` without setting `cache = true`. |
| `removed_cache_dir_variable` | An `outputs` path uses `${CACHE_DIR_<STEP>}`, which no longer exists. |

**Invocation**

| Code | Raised when |
| --- | --- |
| `config_unreadable` | A `-c` config file could not be read, or its JSON/TOML/KEY=VALUE content did not parse. |
| `invalid_param_override` | A `-p` override is not `KEY=VALUE`, or its key is empty. |
| `missing_step_executable` | Packaging was requested but a step's `exec` file does not exist under `steps/`. |
| `environment_check_failed` | `inspect --check-environment` found a required tool, package, or shared library missing. One diagnostic per missing item. |
