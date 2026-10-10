# Dependencies and parallelism

## The DAG

A pipeline is a directed acyclic graph of steps. `depends_on` names the steps that must finish
before another can start. Independent steps can run together when the thread budget permits.

```toml
[steps.prepare]
exec = "prepare.sh"
label = "Prepare inputs"

[steps.analyze]
exec = "analyze.sh"
label = "Analyze"
depends_on = ["prepare"]

[steps.report_a]
exec = "report_a.sh"
label = "Report A"
depends_on = ["analyze"]

[steps.report_b]
exec = "report_b.sh"
label = "Report B"
depends_on = ["analyze"]

[steps.summary]
exec = "summary.sh"
label = "Summary"
depends_on = ["report_a", "report_b"]
```

The two reports may run together; `summary` waits for both. Use `flowrs inspect PIPELINE` to
check the graph. Cycles and unknown dependencies are refused.

## Trigger rules

After upstream steps finish, `trigger_rule` decides whether a step runs. Successful cached
results count as success.

| Rule | Runs when |
| --- | --- |
| `all_success` (default) | The upstream steps succeeded |
| `all_failed` | The upstream steps failed |
| `all_done` | The upstream steps finished, including failure or skip |
| `one_success` | At least one upstream step succeeded |
| `one_failed` | At least one upstream step failed |
| `none_failed` | No upstream step failed; skipped steps are allowed |
| `none_failed_min_one_success` | No upstream step failed and at least one succeeded |
| `none_skipped` | No upstream step was skipped; failures are allowed |
| `always` | No outcome condition, after upstream steps finish |

A failure-reporting step can use `all_done` and inspect `status.json` for the failed branches.
Trigger rules do not bypass cancellation.
With no upstream steps, these rules permit execution.

## Threads and the budget

Set the run's total budget with `-@`:

```bash
flowrs run demo -i input -w work -@ 8
```

Without `-@`, the budget is `pipeline.min_threads` when declared, otherwise the machine's
available CPU count. A supplied budget below the declared minimum is refused.

A step's `threads` is a positive fixed count or `"auto"` (the default). A fixed count above the
run budget is reduced to that budget. Auto allocations share available threads among ready
logical steps. Running executions keep their allocations until they finish.

Use `threads_weight` with auto allocations to give heavier work a larger relative share:

```toml
[steps.align]
exec = "align.sh"
label = "Align"
threads = "auto"
threads_weight = 3

[steps.index]
exec = "index.sh"
label = "Index"
threads = "auto"
```

With both ready under an available budget of eight, the shares are six and two. Weights are
positive ratios, not thread counts, and cannot accompany a fixed `threads` value.
For a single-threaded tool, prefer `threads = 1`.

Scripts receive their allocation as `THREADS`; pass it to the tool's thread option.

## Scattering a step

Use a collection to run one logical step once per item:

```toml
[collections.samples]
source = "${INPUT_DIR}/samples.tsv"
id_column = "sample_id"

[steps.align]
exec = "align.sh"
label = "Align samples"
scatter = "samples"
outputs = ["${ITEM_DIR}/aligned.bam"]

[steps.merge]
exec = "merge.sh"
label = "Summarize alignments"
gather = ["align"]
outputs = ["${OUT_DIR}/summary.tsv"]
```

Collections are headered TSV files or JSON arrays of objects. The source is absolute or relative
to the input directory; only a leading `${INPUT_DIR}` variable is supported. Missing or duplicate
ids, ragged TSV rows, and empty collections are refused.

An item execution receives `FLOWRS_ITEM_ID`, `FLOWRS_ITEM_INDEX`, `FLOWRS_ITEM_FILE`, and
`ITEM_DIR`. Read fields such as input filenames from the JSON item file. Steps over the same
collection share an item's directory, so their declared output paths must differ.

Dependencies between scattered steps over one collection pair by item: `align/S1` precedes
`quantify/S1`. A scalar consumer uses `gather` to wait for the scattered batch. Direct
dependencies between different collections are refused; use a gather step to combine them.

A gather execution reads `FLOWRS_GATHER_MANIFEST` for the item list:

```json
{
  "step": "merge",
  "gathers": ["align"],
  "items": [
    {"id": "S1", "index": 0, "step": "align", "item_dir": "/work/run/items/samples/S1"}
  ]
}
```

Its trigger rule applies to the batch: `all_success` requires successful items; `all_done` also
allows failed or skipped items. Item outcomes are recorded under the scattered step in
`status.json`.

Limit memory or I/O pressure with an item cap:

```bash
flowrs run demo -i input -w work -@ 16 --max-in-flight 6
```

The cap applies per scattered step, alongside the total thread budget. An auto scattered step
shares its allocation among eligible items; a fixed count applies per item, limited to the run
budget. Use the supplied `THREADS` value in the script.

Collection identity covers the parsed format, id column, item order, ids, and fields. Formatting
changes that leave this data unchanged may preserve the identity. A changed identity invalidates
the collection's cached results and, with versions unchanged, prevents resume even with `--force`.

<a id="teardown-steps"></a>

## Teardown steps

A teardown step runs after the main DAG, including after a main-step failure:

```toml
[steps.archive]
exec = "archive.sh"
label = "Archive results"
teardown = true
```

Teardown does not start after cancellation or a setup failure. Teardown steps are outside
`-s`/`-e` slices and run again on resume. They use the thread budget, check declared outputs,
and can fail the run. If main and teardown work both fail, the first failure determines the
exit code.

Teardown siblings can run together; `depends_on` does not order that batch.

| Work | Where to put it |
| --- | --- |
| Archive or publish work required for a successful delivery | Teardown step |
| Summarize specific branches after they finish | Normal step with dependencies and `all_done` |
| Notification whose failure should not fail the run | Lifecycle hook |

Hooks are described in the [manifest reference](manifest-reference.md#pipelinehooks--lifecycle-scripts).
FlowRs attempts scratch cleanup on handled exit unless `--keep-tmp` was supplied.
