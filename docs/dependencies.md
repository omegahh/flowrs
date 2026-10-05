## Dependencies and parallelism

### The DAG

`depends_on` and `gather` define ordering. FlowRs builds a directed graph, rejects cycles at
construction, and schedules by **in-degree**: a step starts the moment its own dependencies are
done, not when a whole layer finishes.

```toml
[steps.prepare]
exec = "prepare.sh"
label = "Prepare inputs"

[steps.analyze]
exec = "analyze.sh"
label = "Analyze"
depends_on = ["prepare"]

[steps.report_a]
exec = "report.sh"
label = "Report A"
depends_on = ["analyze"]

[steps.report_b]
exec = "report.sh"
label = "Report B"
depends_on = ["analyze"]

[steps.summary]
exec = "summary.sh"
label = "Summary"
depends_on = ["report_a", "report_b"]
```

`flowrs inspect` draws what that means — the two reports run together:

```console
$ flowrs inspect full
Steps (6 steps, 4 layers, 1 teardown)

├─ [parallel]
│    ├─ cleanup  Cleanup  → cleanup.sh
│    └─ prepare  Prepare inputs  → prepare.sh
├─ analyze  Analyze  → analyze.sh  2t
├─ [parallel]
│    ├─ report_a  Report A  → report.sh
│    └─ report_b  Report B  → report.sh
└─ summary  Summary  → summary.sh  trigger:all_done
```

Two steps may share one `exec`. `report_a` and `report_b` both run `report.sh`, which reads
`$FLOWRS_UNIT` to tell which one it is.

### Trigger rules

`trigger_rule` decides whether a step runs, given its upstream outcomes. Default `all_success`. A
step whose rule is not satisfied is **skipped**, not failed.

| Rule                          | Runs when                                             |
| ----------------------------- | ----------------------------------------------------- |
| `all_success`                 | No upstream failed and none was skipped (**default**) |
| `all_failed`                  | Every upstream failed                                 |
| `all_done`                    | Every upstream finished, in any state                 |
| `one_success`                 | At least one upstream succeeded                       |
| `one_failed`                  | At least one upstream failed                          |
| `none_failed`                 | No upstream failed; skipped is fine                   |
| `none_failed_min_one_success` | No upstream failed and at least one succeeded         |
| `none_skipped`                | No upstream was skipped                               |
| `always`                      | Unconditionally                                       |

A step with no upstream dependencies always runs, whatever its rule.

```toml
[steps.summary]
exec = "summary.sh"
label = "Summary"
depends_on = ["report_a", "report_b"]
trigger_rule = "all_done"     # summarize whatever finished, even if one report failed
```

### Threads and the budget

`-@ N` sets **one budget shared by the whole run** — not N job slots. Every concurrent step draws
from it.

- `threads = N` costs exactly N permits.
- `threads = "auto"` (the default) splits what is available among the `auto` steps ready alongside
  it. A lone one gets everything; four together get a quarter each.

Spelled `-@` rather than `-j` deliberately: `-j` means _job slots_ in make and cargo, each free to
use as many threads as it likes. This is the opposite, and `-@` is the samtools/bwa spelling.

With `-@ 4` on the pipeline above — `prepare` alone, `analyze` fixed at 2, then two `auto` reports:

```console
$ flowrs run full -i input -w work2 -t run1 -@ 4
     info 26/08/24 13:06:11 [prepare] threads granted: 4       # alone, so the whole budget
     info 26/08/24 13:06:14 [analyze] threads granted: 2       # threads = 2, a fixed cost
     info 26/08/24 13:06:20 [report_a] threads granted: 2      # two auto steps, half each
     info 26/08/24 13:06:20 [report_b] threads granted: 2
```

Omit `-@` and the budget is the pipeline's `min_threads`, or the machine's CPU count.

Four separate concepts control threading, and they answer different questions:

| Concept          | Where           | What it is                                                          |
| ---------------- | --------------- | ------------------------------------------------------------------- |
| `-@ N`           | the command     | The run's whole budget. Every concurrent step draws from this one pool |
| `min_threads`    | `[pipeline]`    | The run's floor: fewer is refused. Also the budget when `-@` is omitted |
| `threads_weight` | a step          | That step's *share* among the `auto` steps ready in the same pass    |
| `teardown = true` | a step         | Same `threads` and `threads_weight` surface, allocated as one batch when the DAG finishes |

A budget above the machine's processor count is warned about, not refused — a cgroup quota,
hyperthreading, and I/O-bound steps are all real reasons to oversubscribe:

```console
$ flowrs run full -i input -w work -@ 64
  warning Thread budget 64 exceeds this machine's 8 available processors; steps may contend for CPU
```

#### `threads_weight` — an uneven share

By default every `auto` step in a ready cohort takes an equal share. When they are not equally
hungry, `threads_weight` says so:

```toml
[steps.align]
exec = "align.sh"
label = "Align"
threads = "auto"
threads_weight = 3    # scales to ~8 threads, so give it the lion's share

[steps.index]
exec = "index.sh"
label = "Index"
threads = "auto"      # weight 1: single-threaded, so a share is wasted on it
```

Under `-@ 8` with both ready together, `align` gets 6 and `index` gets 2.

Three things to know:

- **It only matters when two or more `auto` steps are ready together.** A lone one takes what is
  available whatever its weight, so a weight changes nothing in a linear pipeline.
- **Weights are ratios, not counts.** `3` means three times the share of a step weighted `1`. The
  same manifest divides 6:2 under `-@ 8` and 3:1 under `-@ 4`; scaling every weight changes nothing.
- **It is refused alongside a fixed `threads`.** A fixed count already names the permits the step
  wants, so there is no share left to divide.

To estimate one, use the step's **measured scaling slope**: run it alone at 1, 2, 4, and 8 threads
and see where the wall-clock stops improving. A step that halves from 1 to 2 and gains nothing past
4 deserves roughly 4× the weight of a single-threaded one. Failing that, use the tool's own
preferred `--threads` value as the ratio.

Leftover threads are handed out rather than left idle: three equally-weighted steps under `-@ 8` get
3, 3, and 2. If a cohort is large enough that a share would round below one thread, every member is
charged 1 and the excess waits for a permit — the budget still caps concurrency.

### Scattering a step

A pipeline that processes samples usually runs the same few steps once per sample. Declaring that
once, rather than once per sample, is what `scatter` is for.

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

The collection is a file: a TSV with a header row and one line per item, or a JSON array of objects.
Its source is absolute or relative to the input directory. Only a leading `${INPUT_DIR}` variable
expands; other variables are rejected during manifest validation.
`id_column` names the column or key holding each item's id. FlowRs reads it once, before anything
runs, and refuses a duplicate id, a missing id, a ragged row, or an empty file — so a mistake costs
a second rather than a run.

A scattered step runs once per item, each in its own directory, with its own cache entry, its own
log, and its own line in `status.json`. The variables in
[The runtime contract](runtime-contract.md#conditionally-present) says which item it is:

```bash
# steps/align.sh
# $FLOWRS_ITEM_ID is the sample, $ITEM_DIR is where this sample's outputs go
bwa mem -t "$THREADS" "$REF" "$READS" > "$ITEM_DIR/aligned.bam"
python3 -c "import json,os; m=json.load(open(os.environ['FLOWRS_ITEM_FILE'])); print(m['read1'])"
```

**Dependencies between scattered steps pair by item.** Two steps over the same collection do not
fan out against each other — `align/S1` feeds `quantify/S1`, never `S2`. A step that does not
scatter and depends on one that does must `gather` it instead, and two steps over *different*
collections cannot depend on each other at all: that would be every item of one against every item
of the other, which is a Cartesian product rather than a join. Use a gather step to join them.

A `gather` step waits for **every** instance of the steps it names, then runs once. It reads
`$FLOWRS_GATHER_MANIFEST` for the list:

```json
{
  "step": "merge",
  "gathers": ["align"],
  "items": [
    { "id": "S1", "index": 0, "step": "align", "item_dir": "/.../items/samples/S1" }
  ]
}
```

Whether a gather step runs at all is its `trigger_rule`, read over the *whole batch*: `all_success`
runs it only if every item succeeded, and `all_done` runs it if the batch finished however it went
— which is what a step reporting on failures wants. Each item's exit code is in `status.json`,
under the scattered step's own `items` list.

Concurrency is the run's thread budget, as for any other step, with one addition:

```console
$ flowrs run pipeline -i data -w work -@ 16 --max-in-flight 6
```

`--max-in-flight` caps how many items of one step run at once. It is a queue bound, not a second
resource system — `-@` stays the hard limit — so the effective number is whichever is smaller. Use
it for work that is heavy in memory or I/O rather than in CPU, where the thread count overstates
what the machine can take.

An `auto` scattered step takes one weighted share alongside the other ready logical steps, then
divides that share among its eligible items. Under `-@ 8`, an equally weighted scalar step and a
scattered step each receive four threads. With `--max-in-flight 2`, the scattered step starts two
items with `THREADS=2` each; without that cap, it can start four with `THREADS=1`. Item count does
not multiply the step's weight. Fixed `threads = N` still costs N threads per item.

Shares are computed from currently available threads on each scheduling pass. Running processes
keep their grants until they finish; they are not resized or interrupted to redistribute threads.

> **Scattered steps and caching.** An item's cache entry is keyed on the item's id and the collection
> file's contents, so editing the sample sheet invalidates the batch rather than serving stale
> results. `--resume` refuses a run whose collection file changed, since the completed items were
> computed over a different item set — start a new run instead.

<a id="teardown-steps"></a>

### Teardown steps

`teardown = true` moves a step after the main pipeline, where it runs **whatever the outcome**. This
is where work that comes last goes: archiving, uploading, publishing, writing a run manifest.

```toml
[steps.cleanup]
exec = "cleanup.sh"
label = "Cleanup"
teardown = true
```

```console
     fail 26/08/24 13:16:40 [analyze] exit 3
     info Running 1 teardown step(s)
      run 26/08/24 13:16:40 [cleanup] running...
     info 26/08/24 13:16:40 [cleanup] teardown runs regardless of outcome
   finish 26/08/24 13:16:41 [cleanup] 780ms
    error Pipeline failed: ...
```

Teardown steps are excluded from `-s`/`-e` slices, and `--resume` always re-runs them.

#### A teardown step is a full pipeline step

`teardown = true` changes **when** a step runs, and nothing else. In particular:

- its declared `outputs` are checked, so exiting 0 without writing them is a `MISSING_OUTPUT`
  failure, exactly as in the DAG;
- a failure resolves against your `[[errors]]` table, lands in `status.json` as `resolved_error`,
  and fires the matching `on_error` hook;
- **a failing teardown step fails the run.** The exit code is the step's own, `on_failure` runs
  instead of `on_success`, and `status` in `status.json` reads `failed`.

Design around that last point: if your archive step cannot write the archive, the run did not
succeed, whatever the compute did. When both a DAG step and a teardown step fail, the exit code
reports the *first* failure — the DAG's — and the summary names the teardown step separately.

Its siblings in the batch still run: a failing upload does not prevent the cleanup queued beside it,
and each records its own outcome. A step killed by Ctrl-C is reported as cancelled, not failed, and
does not decide the exit code.

#### Choosing where work goes

Three places, distinguished by what should happen when the work fails:

| Put it in | When | If it fails |
| --- | --- | --- |
| a **teardown step** | its success is part of what the run delivers — archive, upload, publish | the run fails |
| a **hook** | it is a reaction, not delivery — notify, audit, page a team | logged, outcome unchanged |
| a step with `trigger_rule = "all_done"` | it needs a *specific* step's outputs, however that step ended | the run fails |

The last row is worth spelling out, because both options run "at the end":

- work that depends on **a particular step having finished** — summarize whatever reports were
  produced, merge the branches that succeeded — is a normal step with `depends_on` and `trigger_rule
  = "all_done"`. It sits in the DAG, so ordering and inputs are explicit;
- work that depends only on **the run being over** — upload everything in `OUT_DIR`, close an
  external record — is a teardown step. Omit `depends_on`: it does not order the teardown batch.

Work whose failure must not count belongs in a hook — name the script in both `on_success` and
`on_failure` if it should happen either way. See
[`[pipeline.hooks]`](manifest-reference.md#pipelinehooks--lifecycle-scripts). `$TMP_DIR`, the claim file, and a package's
extracted tree are removed for you, so scratch cleanup only needs a hook for paths you created
elsewhere.

Teardown steps declare threads like any other step and draw from the same `-@` budget, so a run
cannot fan out past it just because the DAG finished. The difference is *when*: the whole teardown
set is priced as one batch the moment the DAG completes. So two `auto` teardown steps under `-@ 8`
get four each, and weighting them 3:1 gives six and two:

```toml
[steps.upload_results]
exec = "upload.sh"
label = "Upload results"
teardown = true
threads = "auto"
threads_weight = 3    # parallel upload; wants most of the pool

[steps.write_manifest]
exec = "manifest.sh"
label = "Write run manifest"
teardown = true       # weight 1: single-threaded
```

If the batch asks for more than the budget — several fixed costs, or more steps than permits — the
excess waits for a permit rather than running unbudgeted, exactly as it does inside the DAG.

---
