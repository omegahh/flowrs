## Exit codes

| Code        | Meaning                                                                             |
| ----------- | ----------------------------------------------------------------------------------- |
| `0`         | Success — **and every declared `outputs` file exists**                              |
| `1`–`63`    | Yours, via `[[errors]]`. Passed through as `flowrs run`'s own exit code             |
| `64`–`99`   | FlowRs CLI: 64 validation, 65 bad data, 70 runtime, 77 licence, 78 manifest, 79 grant |
| `120`       | `MISSING_OUTPUT` — exited 0 but a declared output is missing                        |
| `124`       | `TIMEOUT` — killed after exceeding `timeout`                                        |
| `126`/`127` | Not executable / command not found                                                  |
| `128+N`     | Killed by signal N                                                                  |

**77 and 79 are different problems.** 77 means the licence itself is unusable — missing, expired,
wrong machine, bad signature — and you fix it by installing a good one. 79 means the licence is fine
but does not authorize *this encrypted package*: no grant, an expired one, or one issued for a
different build. Only the issuer can fix a 79, so a script seeing it should ask for a (re)grant
rather than re-check the licence file.

**Exit 0 is not enough.** If a step declares `outputs` and any is missing, the step fails with 120:

```console
$ flowrs run liar -i input -w work4 -t miss -e prepare
    error Step 'prepare' exited 0 but didn't produce its declared outputs:
  - /tmp/work4/miss/prepared.txt

This is a silent failure: the step script reported success but failed to write expected outputs. Check the step script for errors.
     fail 26/08/24 13:20:02 [prepare] exit 120
    error Pipeline failed: 0 completed, 1 failed, 0 skipped, 0 cancelled in 128ms
```

The bands are disjoint by design: because your **declared** codes stop at 63, a wrapper reading only
an exit status can always tell your `NO_INPUT_DATA` from a licence failure.

**That covers declared codes, not every code a step can produce.** FlowRs passes a failing step's
exit code through verbatim, so a step that exits 77 — a tool it called returned 77, or a stray `exit
77` — makes `flowrs run` exit 77, indistinguishable from a licence failure to a caller reading only
the status. The pass-through is deliberate: an undeclared code is the only thing that step told you.
Two ways to stay clear of it:

- Declare the codes you care about in `[[errors]]`, keeping them in `1`–`63` where the guarantee
  holds.
- When a wrapper must be certain, read `out/status.json` — it names the failing step alongside its
  code, so no code is ambiguous.

---

## Machine-readable diagnostics

`compile` and `inspect` accept `--json`, which puts a **diagnostics envelope** on stdout. It exists
for automated authoring: a generator or an agent gets each failure as data, with a stable code and a
coordinate into `manifest.toml`, instead of parsing prose.

**All structural findings are reported in one run**, the way a compiler does — so fixing a manifest
is one edit rather than a round trip per mistake:

```console
$ flowrs compile ./my_pipeline --json
{
  "ok": false,
  "exit_code": 78,
  "diagnostics": [
    {
      "code": "unknown_dependency",
      "field": "steps.aling.depends_on",
      "ref": "trimm",
      "message": "Step 'aling' depends on 'trimm', which does not exist.\n\nAvailable steps: aling, qc\n\nCheck for typos in the depends_on list.",
      "hint": "declared steps are: aling, qc"
    },
    {
      "code": "retry_limit_exceeded",
      "field": "steps.qc.retries",
      "ref": "200",
      "message": "Step 'qc' retry count 200 exceeds maximum of 10",
      "hint": "the maximum is 10"
    },
    {
      "code": "unknown_hook_error_code",
      "field": "pipeline.hooks.on_error.NOSUCH",
      "ref": "NOSUCH",
      "message": "[pipeline.hooks.on_error] has a hook for 'NOSUCH', which is neither a declared [[errors]] code nor an engine built-in. …",
      "hint": "known error codes are: BAD_FASTA_SHAPE, BAD_FASTQ_SHAPE, …"
    }
  ]
}
```

The order is deterministic — checks run in a fixed sequence, and findings within one check appear in
the order found — so the same manifest always produces the same array.

The human message still goes to **stderr**, every finding numbered, and a *single* finding prints
with no count or numbering. The exit code is untouched: `78` for a bad manifest, `64` for a bad
invocation. Without `--json`, stdout stays empty.

**What is a contract, and what is not:**

| Field | | |
| --- | --- | --- |
| `code` | **stable** | Match on this. Renaming or removing one is a breaking change |
| `field` | **stable** when present | A dotted path into `manifest.toml`. Omitted for a whole-file problem |
| `exit_code` | **stable** | Always equal to the process's own exit status |
| `fatal` | **stable** when present | `true` when this finding left later checks without a subject, so the list may be incomplete. Absent otherwise — never `false` |
| `ref` | advisory | The single offending value or name, when there is one |
| `line` | advisory | 1-based line, for a raw TOML parse failure |
| `message` | advisory | Human prose. Reworded freely between releases — never parse it |
| `hint` | advisory | Deterministic facts ("declared steps are: …"), never speculative advice |

**`fatal` marks an incomplete list.** Some failures take away the subject a later check needed — an
empty `[steps]` table, a profile naming an undeclared parameter, an unresolvable `depends_on`. Those
carry `fatal: true`, and the checks that needed what they named were skipped rather than run against
something that is not there. Fix them and validate again to see what they were hiding.

It does not mean the array is length one, or that collection stopped: two unresolvable dependencies
are two diagnostics, each `fatal`, because each is a separate mistake.

A check whose subject an earlier check already rejected is **skipped**. With an unresolvable
`depends_on` the cycle check is not attempted, since everything it would report follows from the
dependency already named — the envelope never carries an artifact of a check that could not run. The
skip is as narrow as the dependency: an unresolvable `depends_on` does not suppress the cache
checks, and an undeclared profile parameter does not suppress the check on your
`[params.X.<profile>]` keys, because those read your own declarations rather than the missing thing.

**One limitation: a TOML parse failure carries exactly one diagnostic.** Syntax errors and duplicate
tables are rejected before validation sees the document, and the parser stops at the first problem.
The envelope shape is unchanged; the array is just length one.

On success `compile --json` emits `{"ok": true, "exit_code": 0, "diagnostics": []}`, so a caller can
branch on one field. `inspect --json` differs: on success it prints its manifest projection with
**no** envelope — a second JSON document on the same stream would break every parser — and emits the
envelope only on failure.

**What `compile` checks, and what it cannot.** It validates everything knowable from the manifest
text: the schema, the step graph including cycles, the shape of every constraint expression, and
every declared `default` against its own type, `enum`, and bounds. A `default = 500` under `max =
100` fails `compile` with exit 78 rather than surfacing mid-run, as do bounds admitting no value and
an `enum` entry of a type the param does not declare.

Six codes are outside its reach. Five describe a value from *outside* the manifest —
`unknown_param`, `readonly_override`, `config_unreadable`, `invalid_param_override`,
`missing_required_param` — and one needs a constraint evaluated against resolved values:
`constraint_failed`. `run` reports those as prose, since it has no `--json`; `status.json` is its
machine-readable record.

One subtlety on bounds. A profile override may legitimately *widen* one, so `max = 100` in
`[params.DEPTH]` with `max = 1000` under `[params.DEPTH.ngs]` makes `default = 500` correct whenever
`ngs` is detected. `compile` therefore checks one **window** per declared profile, each value
against the bounds in force alongside it, plus the base pair alone whenever a run can resolve no
profile at all — which is exactly when nothing declares `profiles`. A default illegal in every
window is reported once.

So a base `default` that every profile overrides is never checked against base bounds no run can
read, since an author may keep a sentinel there deliberately.

#### Diagnostic codes

`src/foundation/diagnostic/codes.rs` is the single definition; a test asserts this table lists every
code it declares.

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
<!-- END DIAGNOSTIC CODES -->
