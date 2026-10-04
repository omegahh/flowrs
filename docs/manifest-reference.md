## Manifest reference

Ordered by what you need first. Field names are cross-checked against
[`schema/manifest-v1.json`](../schema/manifest-v1.json), generated from the Rust types — point your
editor at it.

Unknown fields are rejected in the manifest and every fixed section. A typo such as `retreies = 3`
is a parse error; fix it before validation continues.

There are eight top-level elements: `pipeline`, `defaults`, `steps`, `collections`, `params`,
`groups`, `constraints`, and `errors`. Hooks and requirements belong under `pipeline`; detectors,
profile membership, and profile overrides belong under parameters. A manifest needs `[pipeline]`
and at least one step. The other elements are optional.

### `[pipeline]` — identity

```toml
[pipeline]
name = "rnaseq"              # required. No path separators (/, \, ..)
version = "1.2.0"            # required. Your version, free-form
description = "RNA-seq quantification"
author = "Genomics Core"
license = "MIT"
min_threads = 4              # the run's floor, and the budget when -@ is omitted
cache_dir = "shared"         # required if any step sets cache = true
```

`name` and `version` are the only required fields. `cache_dir` is a single relative segment resolved
under `WORK_DIR`, so every cached step lands in one inspectable place.

### `[steps.<name>]` — the unit of work

Only `exec` and `label` are required.

```toml
[steps.align]
exec = "align.sh"                       # required. A file in steps/
label = "Align reads"                   # required. Shown in console and status.json
depends_on = ["trim"]                   # steps that must finish first
scatter = "samples"                     # run once per item of a collection
threads = 4                             # a fixed cost, or "auto"
# threads_weight = 2                    # only with threads = "auto"; see below
timeout = 3600                          # seconds; the step is killed past this
retries = 2                             # attempts after the first failure
retry_delay = 30                        # seconds between attempts
trigger_rule = "all_success"            # when to run, given upstream outcomes
teardown = false                        # true: run after the pipeline, always
outputs = ["${ITEM_DIR}/aligned.bam"]   # checked after exit 0
cache = false                           # reuse across runs
cache_key = ["quality"]                 # params that are part of the cache identity
```

| Field            | Purpose                                                                           |
| ---------------- | --------------------------------------------------------------------------------- |
| `exec`           | The script to run, relative to `steps/`. The interpreter comes from the extension |
| `label`          | Human-readable name for console output and `status.json`                          |
| `depends_on`     | Names of steps that must complete first. This is what builds the DAG              |
| `scatter`        | Run this step once per item of a declared collection. See [Dependencies and parallelism](dependencies.md#scattering-a-step) |
| `gather`         | Wait for every instance of these scattered steps, as one batch                    |
| `trigger_rule`   | Whether to run, given upstream states. See [Dependencies and parallelism](dependencies.md#trigger-rules)                   |
| `timeout`        | Seconds before the step is killed. Records exit 124, `TIMEOUT`                    |
| `retries`        | Retry attempts on failure, max 10. Default 0                                      |
| `retry_delay`    | Seconds to wait between attempts. Default 0                                       |
| `threads`        | `"auto"` to share the budget, or a fixed count. See [Dependencies and parallelism](dependencies.md#threads-and-the-budget) |
| `threads_weight` | This step's share when `threads = "auto"`. Default 1. See [Dependencies and parallelism](dependencies.md#threads-and-the-budget) |
| `teardown`       | Runs after the main pipeline, whatever the outcome. For cleanup                   |
| `outputs`        | Files that must exist after a successful exit, or the step is failed              |
| `cache`          | Reuse this step's results across runs. Requires `cache_dir`                       |
| `cache_key`      | Parameters whose values are part of this step's cache identity                    |

`threads = "auto"` is **exactly that lowercase string.** `"Auto"`, `"AUTO"`, `"max"`, and `"auto "`
are rejected at parse time rather than silently defaulted:

```console
$ flowrs inspect broken
    error Manifest error: invalid thread allocation 'Auto'. String value must be exactly
    "auto"; use a number for a fixed thread count
```

A step cannot both scatter and gather. A separate scalar step gathers the scattered results:

```toml
[steps.summarize]
exec = "summarize.sh"
label = "Summarize alignments"
gather = ["align"]
outputs = ["${OUT_DIR}/summary.tsv"]
```

Use `depends_on` for scalar prerequisites or paired dependencies within one collection. A scalar
consumer must name a scattered upstream in `gather`, without repeating it in `depends_on`.

Scalar `outputs` paths may use `${OUT_DIR}`, `${WORK_DIR}`, `${TMP_DIR}`, or an absolute path.
Writing under `${CACHE_DIR}` requires `cache = true`. Scattered outputs belong under `${ITEM_DIR}`,
including when cached; the engine places a cached item's directory under the cache root.
`${ITEM_DIR}` is unavailable to scalar steps, and `${INPUT_DIR}` is forbidden in outputs.

### `[collections.<name>]` — items for scatter

```toml
[collections.samples]
source = "${INPUT_DIR}/samples.tsv"
id_column = "sample_id"
format = "tsv"
```

`source` and `id_column` are required strings. The source may be absolute or relative to the input
directory; only a leading `${INPUT_DIR}` variable expands. `id_column` names the TSV column or JSON
key holding each item's id. Optional `format` is `"tsv"` or `"json"`; otherwise it is inferred from
the extension (`.tsv`, `.txt`, or `.tab` for TSV, `.json` for JSON).

A collection name is one path component. Item ids are data: use `${ITEM_DIR}` for paths rather than
joining an id yourself. See [scattering a step](dependencies.md#scattering-a-step) for dependencies
and the per-item environment.

### `[defaults]` — fallbacks for every step

```toml
[defaults]
timeout = 7200
retries = 1
retry_delay = 30
```

Three fields only. A step's own value wins where it sets one.

### `[params.<name>]` — what a run can be configured with

Only `type` is required. Types are `string`, `integer`, `number`, `boolean`.

```toml
[params.min_quality]
type = "integer"
default = 20                 # base fallback when no higher tier supplies a value
description = "Minimum base quality"      # shown by `flowrs inspect`
min = 0                      # inclusive lower bound
max = 60                     # inclusive upper bound
exclusive_min = 0            # strict: value must be > 0
exclusive_max = 100          # strict: value must be < 100
increment = 5                # allowed spacing for numeric values
group = "quality"            # references [groups.quality]
readonly = false             # true: -p/-c on this is a hard error
enum = [10, 20, 30]          # the permitted values
```

| Field                             | Purpose                                                                      |
| --------------------------------- | ---------------------------------------------------------------------------- |
| `type`                            | Required. `string`, `integer`, `number`, or `boolean`                        |
| `default`                         | Base fallback; the run fails if no resolution tier supplies a value         |
| `description`                     | Shown by `flowrs inspect`                                                    |
| `min` / `max`                     | Inclusive numeric bounds                                                     |
| `exclusive_min` / `exclusive_max` | Strict numeric bounds                                                        |
| `increment`                       | Numeric values must be an integer multiple of this from `min` (or zero)       |
| `group`                           | UI grouping hint. References `[groups.<name>]`                               |
| `readonly`                        | `-p`/`-c` on this param is a hard error rather than a silent drop            |
| `enum`                            | The permitted values. A value outside the list is refused                    |
| `detector`                        | Script under `bin/` computing a default when no value was supplied           |
| `profiles`                        | Named groups partitioning this parameter's explicit values                  |
| `<profile>` sub-table             | Overrides `default` and numeric bounds for a declared profile                |

`increment` applies to `integer` and `number` parameters. Integer increments must be whole numbers. A value must satisfy the bounds,
increment, and `enum` together. With `min = 0` and `increment = 5`, the allowed lattice is
`0, 5, 10, ...`; `enum` can further reduce that set.

`enum` values are the exact values accepted by the parameter:

```console
$ flowrs run elab -i input -w work -t lab1 -p mode=Fast
    error Validation error: Parameter 'MODE' value Fast not in allowed values:
    ["fast", "slow"]
```

**Resolution order**, highest first:

```
readonly gate > CLI override (-p/-c) > detected > profile default > base default > unset
```

On resume, recorded values sit below explicit overrides and above detection. Readonly parameters
always use the current manifest's defaults, including the selected profile's overrides.

`readonly` refuses an override instead of ignoring it:

```console
$ flowrs run full -i input -w work -t run1 -p engine=slow
    error Validation error: Parameter 'ENGINE' is readonly and cannot be overridden
```

<a id="required-parameters"></a>

**Every declared parameter must resolve to a value.** A parameter without a base `default` may
still receive a detected value, a profile default, or a resume baseline. If no tier supplies it,
the run is refused before any step spawns:

```console
$ flowrs run seq -i input -w work -t run1
    error Validation error: Parameter 'SAMPLE_ID' has no value.

A parameter with no other source of a value must be supplied for the run:

  -p SAMPLE_ID=<value>

or in a config file passed with -c.
```

Every missing parameter is named in one refusal, so supplying three takes one more run rather than
three. Exit 64: the manifest is valid, but the invocation has not supplied every value it needs.

There is no `required = true` key. To require an invocation-supplied value, omit the base default,
profile defaults, and detector. Common ways to provide a value are:

| The value is | Write |
| --- | --- |
| the same for every run | `default = <value>` |
| worked out from the input | a [detector](#detector--a-computed-default) |
| known only per run | neither — the run supplies it with `-p`/`-c` |

Profile-specific defaults are sub-tables named after a profile:

```toml
[params.min_len]
type = "integer"
default = 50

[params.min_len.ngs]      # applies when the detected profile is "ngs"
default = 35

[params.min_len.tgs]
default = 500
min = 100                 # a profile may also tighten or widen bounds
```

Values arrive from `-p KEY=VALUE` (repeatable) or `-c FILE`, where the file is JSON, TOML, or
`KEY=VALUE` lines — detected by extension. All three of these set `quality`:

```bash
echo 'QUALITY=42'      > cfg.env
echo '{"quality": 43}' > cfg.json
echo 'quality = 44'    > cfg.toml
```

<a id="errors--failures-the-pipeline-can-name"></a>

### `[[errors]]` — failures the pipeline can name

```toml
[[errors]]
code = "NO_INPUT_DATA"       # required. A-Z, 0-9, underscore only
exit_code = 20               # required. 1-63, unique across the manifest
category = "input"           # required. Free-form grouping label
message = "No input data found"   # required. Static, no placeholders
retryable = false            # retry the step on this error?
max_retries = 2              # overrides the step's own retries
help_url = "https://..."     # troubleshooting link
```

`exit_code` must be **1–63** — your band, disjoint from every code FlowRs returns, so a caller
reading only an exit status can tell "the pipeline reported a declared error" from "FlowRs refused
to run". `code` must be `A-Z`, `0-9` and `_` only: the step looks the name up verbatim in
`FLOWRS_ERROR_MAP`, so anything else would be declarable but unreachable from `die`.

A step reports one by _code_, and the stdlib translates:

```bash
die NO_INPUT_DATA "nothing under ${INPUT_DIR}"
```

The engine maps the code back and records the whole definition:

```json
{
  "status": "failed",
  "exit_code": 20,
  "error": "No input data found",
  "resolved_error": {
    "code": "NO_INPUT_DATA",
    "exit_code": 20,
    "category": "input",
    "message": "No input data found",
    "retryable": false
  }
}
```

`flowrs run` then exits **20** — your code, passed through verbatim.

`retryable = true` with `max_retries = 2` gives three attempts, overriding a step-level
`retries = 0`:

```
    summa [ERROR] [FLAKY] pretend the network died
  warning Retrying step 'summary' (attempt 2)
    summa [ERROR] [FLAKY] pretend the network died
  warning Retrying step 'summary' (attempt 3)
    summa summary failed (exit 21)
```

`category` is descriptive metadata for triage and dashboards. Control flow belongs to step outcomes
and trigger rules.

### `[pipeline.hooks]` — lifecycle scripts

```toml
[pipeline.hooks]
on_start = ["start.sh"]        # the run exists, before anything else
on_success = ["success.sh"]    # the run completed successfully
on_failure = ["failure.sh"]    # the run did not succeed, however it ended
on_error.NO_INPUT_DATA = ["no-input.sh"]   # a step failed with this error code
```

Four hooks, because there are four questions to ask. Placement is the declaration:

| You want it… | Use |
| --- | --- |
| to **gate** the run | not a hook — the first step of your DAG |
| when the run begins | `on_start` |
| delivered on completion | `on_success` |
| whenever the run failed | `on_failure` |
| on one specific failure | `on_error.CODE` |

Each name resolves to **`hooks/<script>`** in the pipeline directory. Write the bare filename:
`"start.sh"`, not `"hooks/start.sh"`. `flowrs inspect` lists any hook script it cannot find.

A hook script is resolved exactly as a step is: **the extension picks the interpreter**, and the
executable bit is not consulted. So a `.sh` hook runs under bash, and a compiled or extensionless
one is executed directly — in that case give it a shebang, since the kernel has nothing else to
hand it to.

Each execution writes `logs/hooks/<phase>/<script>.log`, and the stdlib log helpers work exactly as
in a step. `status.json` keeps a hook's exit code, timings, and, on failure, its stderr.

**A hook never delays the run's work, and its failure never fails it** — `on_start` included. Every
hook starts at its moment and the pipeline carries on: a slow `on_start` does not hold the detectors,
a slow `on_error` does not hold the DAG, and neither holds a step or the exit code. The run waits for
them exactly once, after every step has finished, so nothing outlives the run and every execution
still reaches `status.json`.

The one thing that waits is the `success`/`error` summary line, which is printed after that wait so
it describes the whole invocation, hooks included — nothing prints below it. A slow ending hook
therefore holds the line back, bounded by the hook timeout.

A hook is a side-channel reaction: unaffected by `-s`/`-e`/`-k`, absent from `status.json`'s step
map, and unable to change the outcome it reports on. So two things belong elsewhere:

- **Work that must gate the run** is the first step of your DAG, where a failure does fail the run
  and `-s` can target it. Give your other root steps `depends_on = ["<that step>"]`, or they run
  alongside it rather than after it.
- **Delivery work at the end** is a teardown step — see [Teardown steps](dependencies.md#teardown-steps).

`on_error` keys may name a declared code or a built-in: `TIMEOUT`, `MISSING_OUTPUT`,
`NOT_EXECUTABLE`, `COMMAND_NOT_FOUND`, `UNKNOWN_ERROR`, `SIGINT`, `SIGABRT`, `SIGKILL`, `SIGSEGV`,
`SIGTERM`, `SIGNAL`. A **cancelled** step fires no `on_error`: you stopped the run, which is not a
fault.

`on_start` fires as soon as the pipeline is unpacked — before parameters resolve and before any
detector runs — so a run that dies during resolution has still announced itself. It sees the engine
paths (`$OUT_DIR`, `$INPUT_DIR`, …) but **not** your resolved parameters, which do not exist yet.
Nothing waits for it, so do not use it to prepare what a step reads.

Every hook sees the same `$TMP_DIR` a step does, created before `on_start` and removed only after
the last hook finishes. So a terminal hook can read what the run left there — a summary a teardown
step wrote — and what a hook writes there is cleaned up with the run.

`on_success` and `on_failure` are the two endings, and exactly one runs, last of all, after teardown
steps. `on_failure` covers every way a run can end badly, **including Ctrl-C**. `$EXIT_CODE` is set
for `on_success` too (as `0`), so a script in both lists reads the same variable.

A cancelled run says so outright: `$CANCELLED` is `1` and `$CANCELLED_BY` carries the signal (`2`
for SIGINT, `15` for SIGTERM). Both are **absent** otherwise, so their presence is the answer. Do
not infer cancellation from `$EXIT_CODE` — `128 + N` is a band a step reaches on its own, and an
OOM-killed step reports `137` with nobody having stopped the run.

```bash
if [[ -n "${CANCELLED:-}" ]]; then
  notify "run stopped by signal ${CANCELLED_BY}"
else
  notify "run failed: ${FAILED_STEP:-during setup} (exit ${EXIT_CODE})"
fi
```

Once `on_start` has fired, an ending is owed even if the run never reaches its first step: a bad
`-s`, a `-@` below `min_threads`, an unknown `-p`, or a Ctrl-C during setup all reach `on_failure`
and all write a `status.json`. Such a run fires **no** `on_error[CODE]` — those keys name pipeline
failure codes, and a mistyped flag is not one. A failure *before* `on_start`, such as an invalid
licence, fires nothing, since no hook had announced the run.

Hooks already started are **not** interrupted by the signal that cancelled the run, including
`on_error`. Each is bounded by the hook timeout instead. Cancellation does not start a new
`on_error` reaction, but the run waits for notifications already in flight.

System cleanup needs no hook. The output-directory claim is released and a package's decrypted
tree is removed on every handled ending. Scratch survives a failure or signal; a clean run removes
it unless `--keep-tmp` was supplied.

<a id="detector--a-computed-default"></a>

### `detector` — a computed default

**A detector computes one parameter's default value.** Some values cannot be written into a
manifest, because they are a property of the *input* or the machine rather than the pipeline.
Without a default such a parameter is [required](#required-parameters) and every run must pass `-p`;
a detector is the alternative — a script that works the value out by looking.

Any parameter may declare one. Nothing else may.

```toml
[params.READ_LENGTH]
type = "integer"
detector = "probe_reads.sh"   # a script in bin/
default = 150                 # optional: the fallback if the detector reports nothing
```

```toml
[pipeline]
detector_timeout = 60         # seconds any one detector may take. Default 60
```

The timeout is pipeline-level because several parameters may share one script — a number on the
parameter would need reconciling against its co-tenants.

Detection is a *default*, so it sits below `-p`/`-c` and above the declared defaults:

```text
readonly gate > CLI override (-p/-c) > detected > profile default > base default > unset
```

An explicit `-p` therefore **skips the detector entirely** — it does not run. A `--resume` baseline
counts as supplied for the same reason, so a resumed run cannot move onto a different value than its
completed steps used.

Four rules worth knowing before you write one:

- **`detector` + `readonly` is refused.** `readonly` means *named constant*; a value recomputed each
  run is not one.
- **`detector` + `default` is fine**, and the default is the fallback — detection is then an
  optimisation rather than a hard dependency.
- **One script may answer for several parameters.** Named from two parameters it is spawned
  **once**, reporting a line for each, so a probe that walks the input tree does it in one pass.
- **A detector may only answer for parameters that named it.** Anything else is ignored with a
  warning, so the manifest stays the record of what is detected.

Detectors run in parallel, each drawing a share of the `-@` budget, each with its own console line
and its own log at `logs/detectors/<script>.log`.

### `profiles` — the defaults one parameter selects

Once a parameter's value is known, *other* parameters can take their defaults from it. `profiles`
groups one parameter's values into named categories, and each category names a set of defaults
elsewhere in `[params]` — so one manifest carries defaults for several kinds of input.

**A profile is an attribute of the parameter that produces the category**, and at most one parameter
per pipeline may carry it:

```toml
[params.SEQTYPE]
type = "string"
enum = ["SINGLE", "PAIRED", "TGSONT"]
detector = "detect.sh"        # optional — the value may equally come from -p

[params.SEQTYPE.profiles]
ngs = ["SINGLE", "PAIRED"]
tgs = ["TGSONT"]
```

Detection and categorisation are independent: a parameter can be detected without grouping anything
(`READ_LENGTH` above), and a categoriser can be supplied by hand rather than probed for.

**The categories must partition the parameter's whole domain** — every value claimed by exactly one
profile, none twice, none left over. That is checked at `compile`, so a profiled parameter needs a
closed domain: an `enum` for strings and numeric parameters, or the boolean values `true` and
`false`.

Numeric profiles list individual values, just like string profiles. They do not define intervals:
`[100, 150]` means those two values only.

```toml
[params.READ_LENGTH]
type = "integer"
enum = [100, 150, 250, 1000, 10000]

[params.READ_LENGTH.profiles]
short  = [100]
medium = [150, 250]
long   = [1000, 10000]
```

A boolean partitions `{true, false}` as a list: `fast = [false]`, `normal = [true]`.

**What a category may key.** `[params.X.<profile>]` sets another parameter's default per category,
with two exclusions — both manifest errors rather than dead weight: the profiled parameter itself
(it *produces* the category) and any parameter with a `detector` (detection outranks every default,
so one could never win). `readonly` is deliberately *not* excluded: it governs who may set a value,
profiles govern whether it varies by category, and the two compose.

**The categoriser is an ordinary parameter.** Its value resolves first, through the same tiers as
any other; then it selects a category; then everything else resolves with that category's defaults
in force. So an explicit `-p` on it skips its detector and still selects a category:

```console
$ flowrs run prof -i input -w workp -t prof1            # nothing supplied: the detector runs
      run 26/08/24 13:06:11 [detector] detecting SEQTYPE...
     info 26/08/24 13:06:11 [detector] scanning input directory
 profiled 26/08/24 13:06:12 SEQTYPE = TGSONT (matched profile: tgs)
     info 26/08/24 13:06:12 [show] SEQTYPE=TGSONT MIN_LEN=500

$ flowrs run prof -i input -w workp -t prof3 -p seqtype=PAIRED   # supplied: no detector runs
 profiled 26/08/24 13:07:04 SEQTYPE = PAIRED (user set)
     info 26/08/24 13:07:04 [show] SEQTYPE=PAIRED MIN_LEN=35
```

The `profiled` line carries no unit: the value is the run's however it arrived, and the
parenthetical says which — `(user set)` or `(matched profile: <name>)`. The detector itself reports
under its own `[detector]` unit. A resumed run counts as supplied, so resuming cannot land on a
different profile than the steps it is continuing were computed under.

The detector's contract is simple: **it writes `[FLOWRS:PARAM] NAME=VALUE` to stderr**, and those
lines are its answers. `report_param` is the stdlib helper, in every language. The line names its
own subject, which is what lets one script answer for several parameters. It receives `-i <input>`
and `-o <out>` and nothing else:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Called only for parameters no value was supplied for. Decide from the data and report each answer.
# `log_info`/`report_param` need no sourcing, exactly as in a step — see [Stdlib](stdlib.md).
# The arguments are flags, so parse them — do not assume $1 is the input directory.
input=""
while getopts "i:o:" opt; do
  case "$opt" in
    i) input="$OPTARG" ;;
    *) : ;;
  esac
done
log_info "looking for paired FASTQ under ${input}"
if ls "${input}"/*.fastq.gz >/dev/null 2>&1; then
  report_param SEQTYPE PAIRED
else
  report_param SEQTYPE TGSONT
fi
```

Four rules follow from the tag, and they are the whole contract:

- **The tag is the only channel.** An omitted answer uses that parameter's declared default with
  a warning, if one exists. Without a default it fails resolution, whatever the detector wrote
  on stdout.
- **Position does not matter.** Log freely before and after it, in colour if you like — the value is
  found wherever it appears and ANSI codes are stripped.
- **Answer each parameter once.** Two claims for one parameter is a hard failure, not first-wins:
  choosing would make the run depend on print order. Two *different* parameters is exactly how one
  script answers for both.
- **Stdout is yours.** The engine reads no value from it.

**A detector is run exactly as a step is**, so what a step relies on it can too: Ctrl-C stops it
promptly rather than waiting out `timeout`, and a tool it backgrounds is killed with it. Everything
it writes goes to `logs/detectors/<script>.log`, its `INFO`/`WARN`/`ERROR` lines reach the console under the
usual verbosity rules, `die` with a declared `[[errors]]` code works, and a nonzero exit fails the
run before any step starts.

It gets the engine paths a step gets — `INPUT_DIR`, `OUT_DIR`, `WORK_DIR`, `TMP_DIR`, `LOG_DIR`,
`THREADS`, and `TASKID` when the run has one — so the stdlib is available on the
same terms. `$THREADS` is that detector's share of the `-@` budget; detectors may run alongside
one another. **Resolved parameters are not there**: deciding them is what the detector is part of.

Whichever way a value arrived, it is validated against the param's declaration — an undeclared
`enum` value or one outside `min`/`max` is refused. **A detected value that fails is fatal even when
the param has a `default`**: reporting *nothing* can be honest, and then the default applies with a
warning, but a garbage value never is, and falling back silently would let a probe that broke months
ago keep looking healthy.

`status.json` records each detector that ran, under `detectors`:

| Field | Meaning |
| --- | --- |
| `script` | The script under `bin/`, as the manifest names it |
| `detected` | Map of every parameter it answered to the reported string value |
| `status` | `completed` or `failed` |
| `started_at`, `finished_at`, `duration_ms` | The span of the one process |

The map key is the detector unit name, such as `detectors/probe_reads`; it is also the log path
without `logs/` and `.log`. One record per *script*, not per parameter: two parameters sharing a
probe share its span, because it ran once. A parameter whose value was supplied has no record — its
detector never ran. The category the run resolved into is `profile`, beside it. `params.json`
records the resolved values.

### `[pipeline.requires]` — advisory environment notes

```toml
[pipeline.requires]
tools = ["samtools", "bwa"]     # must resolve on PATH
python = ["numpy", "pysam"]     # import names, not distribution names
r = ["ggplot2"]                 # package names
```

Advisory only: declaring a requirement installs nothing and nothing is checked during a run. `flowrs
inspect --check-environment` reports what is missing. Versions are deliberately absent — there is no
portable way to ask an arbitrary tool its version, and an unchecked constraint reads as a guarantee.

For a pipeline directory, this also reads ELF dependency metadata without executing its binaries.
Install `readelf` (binutils) and make `ldconfig` available on `PATH`. The check resolves direct and
transitive library names, including `$ORIGIN` paths; it does not validate symbols or library
versions. Other loader tokens such as `$LIB` and `$PLATFORM` are not expanded and can cause a
library to be reported missing.

### `[[constraints]]` — rules across parameters

```toml
[[constraints]]
when = "QUALITY > 50"
require = "MESSAGE != hello"
message = "High quality needs a custom message"
```

Left side names a parameter, right side is a literal; operators are `==`, `!=`, `>`, `<`, `>=`,
`<=`. When `when` holds and `require` does not, the run stops before any step:

```console
$ flowrs run full -i input -w work -t con1 -p quality=55
    error Validation error: High quality needs a custom message
```

### `[groups.<name>]` — parameter grouping for UIs

```toml
[groups.quality]
description = "Quality filtering"
order = 1
```

Presentation metadata. Nothing in the engine reads it.

---
