# Reading status.json

Read status.json after a run. The file is written atomically and incrementally. It is the
machine-readable run result; console prose is not a data interface.

## Location And Version

- Without -t, read WORK_DIR/status.json.
- With -t ID, read WORK_DIR/ID/status.json.
- schema_version is always present. The current version is 3.
- Treat an unknown schema_version as unreadable until the reader is updated.
- Optional fields are absent, never null. Test key presence.

## Top-Level Fields

| Field | Type | Meaning |
| --- | --- | --- |
| schema_version | integer | Meaning version of this document |
| pipeline | string | Pipeline name |
| task_id | string, absent | Supplied task id |
| status | string | running, completed, or failed for the run |
| started_at | string | RFC 3339 start time |
| finished_at | string, absent | RFC 3339 finish time |
| detectors | object, absent | Detector executions keyed by unit name |
| profile | string, absent | Selected profile category |
| lifecycle_hooks | object, absent | Hook execution records |
| steps | object | Step and scattered-instance records keyed by step or step/item key |
| version_fingerprint | object, absent | engine_version and pipeline_version used for resume |
| input_fingerprint | string, absent | Input-tree stat fingerprint when cache_dir is declared |
| collections | object, absent | Collection content digests keyed by collection name |
| failure | object, absent | Pre-step failure with code and message |
| cancelled_by | string, absent | Signal name such as SIGINT |

The top-level status is completed only when the run and all required teardown work succeed. A
cancelled run finalizes as failed and sets cancelled_by. A step failure is recorded on its step;
failure is used for a failure before any step ran.

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
| duration_ms | integer, absent | Process duration across attempts |
| attempts | integer, absent | Final attempt number; absent for a single attempt |
| skip_reason | string, absent | user, resume, filtered, or cancelled |
| resolved_error | object, absent | Error definition resolved from the exit code |
| teardown | boolean, absent | Present and true for a teardown step |
| collection | string, absent | Collection for a scattered step or item |
| item_id | string, absent | Original collection item id for an item row |
| items | array, absent | Aggregate scattered-step item summaries |

cached means outputs exist and were reused. skipped means no process ran; inspect skip_reason.
The filtered and cancelled reasons do not imply outputs exist. The user and resume reasons assert
that outputs are available.

## Scattered Steps

A scattered step has one aggregate row keyed by its logical step name and one item row per item.
The aggregate row has collection and items, and no item_id. Each item row has item_id and
collection. The items array preserves collection-file order and contains:

~~~json
{
  "id": "S1",
  "index": 0,
  "status": "completed",
  "exit_code": 0
}
~~~

The item id is the original value from the collection file. The key used in the steps object is
an encoded filesystem-safe item key and is not the id. Derive per-item paths from ITEM_DIR, never
from item_id.

## Detector Records

Each detector that actually ran is keyed by its unit name:

| Field | Meaning |
| --- | --- |
| script | Filename under bin/ |
| detected | Map from parameter name to reported string value |
| status | Detector result status |
| started_at | Start time |
| finished_at | Finish time |
| duration_ms | Duration |

A supplied or resumed parameter skips its detector, so no record is written for that execution.
Several parameters may share one detector record.

## Hook Records

lifecycle_hooks contains on_start, on_success, on_failure, and on_error maps/lists when hooks ran.
Each hook execution records:

| Field | Meaning |
| --- | --- |
| script | Hook filename |
| exit_code | Hook process code |
| status | completed, failed, or skipped when the hook process could not be started |
| started_at, finished_at | Times when available |
| duration_ms | Duration when available |
| error | Hook failure text when available |

Hook failure is recorded but never changes the run outcome.

## Failure And Resume

failure appears only for a failure before any step ran:

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
- Treat absent optional fields as inapplicable.
- Use duration_ms for elapsed time; timestamps have second precision.
- Preserve unknown additive fields and reject only an unknown schema_version or a changed meaning.
