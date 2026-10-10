# Reading status.json

Read status.json after a run. The file is written atomically and incrementally. It is the
machine-readable run result; console prose is not a data interface. Early validation refusals can
leave no record. Check that the file belongs to this invocation before using a prior run's result.

## Location And Version

- Without -t, read WORK_DIR/status.json.
- With -t ID, read WORK_DIR/ID/status.json.
- schema_version is required. The current version is 3.
- Treat an unknown schema_version as unreadable until the reader is updated.
- Optional fields are omitted rather than null. Test key presence.

## Top-Level Fields

| Field | Type | Meaning |
| --- | --- | --- |
| schema_version | integer | Meaning version of this document |
| pipeline | string | Pipeline name |
| task_id | string, absent | Supplied task id |
| status | string | running, completed, or failed for the run |
| started_at | string | RFC 3339 start time |
| finished_at | string, absent | RFC 3339 finish time |
| detectors | object, absent | Available successful detected values grouped by unit name |
| profile | string, absent | Selected profile category |
| lifecycle_hooks | object, absent | Hook execution records |
| steps | object | Step and scattered-instance records keyed by step or step/item key |
| version_fingerprint | object, absent | engine_version and pipeline_version used for resume |
| input_fingerprint | string, absent | Input-tree stat fingerprint when cache_dir is declared |
| collections | object, absent | Parsed collection digests keyed by collection name |
| failure | object, absent | Run-level failure with code and message, often during setup |
| cancelled_by | string, absent | Signal name such as SIGINT |
| cache_bindings | object, absent | Adopted cache marker paths mapped to identity hashes |

The top-level status is completed only when the run and all required teardown work succeed. A
cancelled run finalizes as failed and sets cancelled_by. Ordinary step failures are recorded on
their step; failure records an error reported by the run layer, including setup failures.

## Step Status

Each value in steps has:

| Field | Type | Meaning |
| --- | --- | --- |
| status | string | pending, running, completed, failed, skipped, cancelled, or cached |
| label | string | Manifest label |
| started_at | string, absent | Process start |
| finished_at | string, absent | Process finish |
| exit_code | integer, absent | Process or synthesized code |
| error | string, absent | Failure text |
| duration_ms | integer, absent | Elapsed time across attempts, including retry delays |
| attempts | integer, absent | Final attempt number; absent for a single attempt |
| skip_reason | string, absent | user, resume, filtered, or cancelled |
| resolved_error | object, absent | Error definition resolved from the exit code |
| teardown | boolean, absent | Present and true for a teardown step |
| collection | string, absent | Collection for a scattered step or item |
| item_id | string, absent | Original collection item id for an item row |
| items | array, absent | Aggregate scattered-step item summaries |

cached means outputs exist and were reused. skipped means no process ran; inspect skip_reason.
The filtered and cancelled reasons do not imply outputs exist. The user reason assumes outputs are available without verifying them; resume retains prior
completed results. Neither is a fresh output check.

## Scattered Steps

A scattered step has one aggregate row keyed by its logical step name and one item row per item.
The aggregate row has collection and items, and no item_id. Each item row has item_id and
collection. The items array preserves collection-file order. Its optional fields include exit_code and
skip_reason (user, resume, filtered, or cancelled). A completed item can look like:

~~~json
{
  "id": "S1",
  "index": 0,
  "status": "completed",
  "exit_code": 0
}
~~~

The item id is the original value from the collection file. The key used in the steps object is
an encoded filesystem-safe item key and is not the id. Derive per-item paths from ITEM_DIR rather than item_id.

## Detector Records

Available successful detector answers are grouped by script under its unit name:
`detectors/<script-stem>`, with the filename extension omitted.

| Field | Meaning |
| --- | --- |
| script | Filename under bin/ |
| detected | Map from parameter name to reported string value |
| status | completed for these successful answer records |
| started_at | Start time |
| finished_at | Finish time |
| duration_ms | Duration |

These records are not a complete execution history. Silent and failed executions can lack records;
a later detection or resolution failure can also prevent prior answers from being recorded. Read
logs/detectors and the top-level failure for those cases. Supplied or resumed values bypass detection
for that parameter, but a shared script may still run for other parameters. Several answers from one
script share a record.

## Hook Records

lifecycle_hooks contains on_start, on_success, on_failure, and on_error maps/lists when hooks ran.
Each hook execution records:

| Field | Meaning |
| --- | --- |
| script | Hook filename |
| exit_code | Process code; 0 for a missing script, -1 when no process code is available |
| status | completed, failed, or skipped for a missing script |
| started_at, finished_at | Times when available |
| duration_ms | Duration when available |
| error | Hook failure text when available |

Missing scripts and preparation failures have records. Process launch failures warn without a
record. Hook failures do not change the run outcome; use logs and warnings alongside this map.

## Failure And Resume

failure can describe a setup failure:

~~~json
{"code": "missing_required_param", "message": "Parameter 'SAMPLE' has no value"}
~~~

version_fingerprint contains:

~~~json
{"engine_version": "1.11.0", "pipeline_version": "1.0.0"}
~~~

Use input_fingerprint and collections to explain a refused resume. Do not infer cache validity
from timestamps; use the status and cache result.

## Consumer Rules

- Match status and skip_reason values, not human error text.
- Read the step's exit_code together with its key to distinguish a step exit 77 from a licence
  failure.
- Treat absent optional fields as unavailable. Omission does not prove a detector or hook did not run.
- Use duration_ms for elapsed time; timestamps have second precision.
- Preserve unknown additive fields and reject only an unknown schema_version or a changed meaning.
