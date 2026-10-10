# Manifest reference

A pipeline directory contains `manifest.toml` and its scripts. The manifest declares what to run,
which inputs and parameters it needs, and where results should appear.
Point your editor at [the JSON schema](../schema/manifest-v1.json); use `flowrs compile DIR` to
check types, dependencies, and semantic rules. Unknown fields are rejected.

A manifest needs `[pipeline]` and at least one `[steps.<name>]`. Other sections are optional.

### `[pipeline]` - identity

```toml
[pipeline]
name = "rnaseq"
version = "1.2.0"
description = "RNA-seq quantification"
author = "Genomics Core"
license = "MIT"
min_threads = 4
cache_dir = "shared"
detector_timeout = 60
```

| Field | Meaning |
| --- | --- |
| `name`, `version` | Required strings; version is author-assigned |
| `description`, `author`, `license` | Descriptive metadata |
| `min_threads` | Minimum run budget; supplies the default when declared |
| `cache_dir` | One relative directory name under `WORK_DIR`; required for cached steps |
| `detector_timeout` | Seconds per detector execution; default 60 |
| `hooks`, `requires` | Lifecycle scripts and advisory environment requirements; see below |

Pipeline, step, and collection names cannot be empty, contain path separators, or contain `..`.
Use bare filenames for step executables, detectors, and hooks.

<a id="stepsname--the-unit-of-work"></a>

### `[steps.<name>]` - the unit of work

```toml
[steps.align]
exec = "align.sh"
label = "Align reads"
depends_on = ["trim"]
scatter = "samples"
threads = 4
timeout = 3600
retries = 2
retry_delay = 30
trigger_rule = "all_success"
outputs = ["${ITEM_DIR}/aligned.bam"]
```

| Field | Meaning |
| --- | --- |
| `exec`, `label` | Required filename under `steps/` and human-readable label |
| `depends_on` | Prerequisite step names |
| `scatter` | Collection name; run once per item |
| `gather` | Scattered step names whose batches must finish |
| `threads` | Positive fixed count, limited to the run budget, or `"auto"` (default) |
| `threads_weight` | Positive relative share for auto allocations; default 1 |
| `timeout` | Seconds before termination with `TIMEOUT` (124); unset means no timeout |
| `retries` | Additional attempts after failure; default 0, maximum 10 |
| `retry_delay` | Seconds between attempts; default 0 |
| `trigger_rule` | Upstream outcome condition; default `all_success` |
| `teardown` | Run after the main DAG, including failure, unless cancelled; default false |
| `outputs` | Paths checked for existence after exit 0 |
| `cache` | Reuse declared results across runs; default false |
| `cache_key` | Parameter names that affect cached results |

Use `depends_on` for scalar prerequisites or paired dependencies within one collection.
A scalar consumer lists a scattered upstream in `gather`, without repeating it in `depends_on`.
A step cannot both scatter and gather; teardown steps cannot scatter.

```toml
[steps.summarize]
exec = "summarize.sh"
label = "Summarize alignments"
gather = ["align"]
outputs = ["${OUT_DIR}/summary.tsv"]
```

Scalar outputs accept a leading `${OUT_DIR}`, `${WORK_DIR}`, `${TMP_DIR}`, or an absolute path.
`${CACHE_DIR}` requires `cache = true`. Scattered outputs require `${ITEM_DIR}`, including cached
outputs. `${INPUT_DIR}`, unknown or additional variables, and `.` or `..` components are refused.
Steps sharing an item's directory must declare distinct output paths.

See [Dependencies and parallelism](dependencies.md) for trigger rules, thread allocations,
scatter/gather, and teardown, and [Caching](running.md#caching) for reuse limits.

### `[collections.<name>]` - items for scatter

```toml
[collections.samples]
source = "${INPUT_DIR}/samples.tsv"
id_column = "sample_id"
format = "tsv"
```

`source` and `id_column` are required. The source is absolute or relative to the input directory;
only a leading `${INPUT_DIR}` variable is supported. `id_column` names the TSV column or JSON key
holding the item id. Optional `format` is `"tsv"` or `"json"`; otherwise the extension selects
TSV (`.tsv`, `.txt`, `.tab`) or JSON (`.json`).

TSV needs a header and consistent row widths; JSON needs an array of objects. Ids must be present,
non-empty, and unique, and the collection must contain items. Item ids are data, not path names:
use `ITEM_DIR` and read fields from `FLOWRS_ITEM_FILE`.

### `[defaults]` - step fallbacks

```toml
[defaults]
timeout = 7200
retries = 1
retry_delay = 30
```

These are the three supported fields. A step's own value overrides its fallback.

### `[params.<name>]` - run configuration

```toml
[params.min_quality]
type = "integer"
default = 20
description = "Minimum base quality"
min = 0
max = 60
increment = 5
group = "quality"
readonly = false
enum = [10, 20, 30]
```

| Field | Meaning |
| --- | --- |
| `type` | Required: `string`, `integer`, `number`, or `boolean` |
| `default` | Base fallback value |
| `description` | Text shown by inspect |
| `min`, `max` | Inclusive numeric bounds |
| `exclusive_min`, `exclusive_max` | Strict numeric bounds |
| `increment` | Numeric spacing from `min`, or zero when `min` is absent |
| `enum` | Typed list of permitted values |
| `group` | Name of a declared parameter group |
| `readonly` | Refuse explicit `-p`/`-c` overrides; default false |
| `detector` | Filename under `bin/` that computes a default |
| `profiles` | Categories selected by this parameter's value |
| Profile sub-tables | Category-specific default and numeric bounds |

Numeric bounds, increment, and enum apply together. Integer increments must be whole numbers.
Parameter names are case-insensitive when supplied; scripts receive uppercase environment names.

Resolution uses, highest first:

```text
readonly gate > -p/-c > detected > profile default > base default > unset
```

On resume, recorded values sit below explicit overrides and above detection. Readonly parameters
use the current manifest's defaults, including profile overrides; they cannot have detectors.

<a id="required-parameters"></a>

A declared parameter must resolve before steps start. If no default, detector, profile default,
or resume baseline supplies it, use `-p KEY=VALUE` or `-c FILE`. Missing parameters are reported
together at exit 64. There is no `required = true` field.

Config files accept JSON, TOML, or `KEY=VALUE` lines, selected by extension.
Explicit `-p` values win over config values.

<a id="detector--a-computed-default"></a>

### `detector` - a computed default

```toml
[params.read_length]
type = "integer"
detector = "probe_reads.sh"
default = 150
```

The detector receives `-i INPUT_DIR -o OUT_DIR` and the unit environment, without resolved
parameters. Report a value to stderr:

```bash
report_param READ_LENGTH 250
# emits [FLOWRS:PARAM] READ_LENGTH=250
```

A supplied or resumed value bypasses detection for that parameter. A script shared by other
unsupplied parameters can still run; it runs once for the parameters needing answers.

Report each answer once and only for parameters naming that script. Extra answers warn and are
ignored. An omitted answer warns and uses the base default if present; without it, resolution
fails. A nonzero exit, timeout, duplicate answer, or invalid value fails the run even with a default.

Detector logs are under `logs/detectors/`. Available successful detected values are grouped by
script in `status.json.detectors`; this is not a complete detector execution history. Silent or
failed executions can lack records, so consult logs and the run's failure. Resolved values are
saved in `params.json`.

### `profiles` - category-specific defaults

At most one parameter selects profiles. Its categories partition its domain: a string or numeric
selector needs an enum; a boolean selector has the domain `true` and `false`.

```toml
[params.read_type]
type = "string"
enum = ["single", "paired"]
default = "single"

[params.read_type.profiles]
single = ["single"]
paired = ["paired"]

[params.min_len]
type = "integer"
default = 50

[params.min_len.single]
default = 35

[params.min_len.paired]
default = 75
```

Member lists contain individual values, including for numeric selectors. Profile overrides allow
`default`, `min`, `max`, `exclusive_min`, `exclusive_max`, and `increment`.
Do not place an override on the selector itself or on a parameter with a detector.
Readonly parameters may have profile overrides.

<a id="errors--failures-the-pipeline-can-name"></a>

### `[[errors]]` - named failures

```toml
[[errors]]
code = "NO_INPUT_DATA"
exit_code = 20
category = "input"
message = "No input data found"
retryable = false
max_retries = 2
help_url = "https://example.org/help/no-input"
```

`code`, `exit_code`, `category`, and `message` are required. Codes use uppercase ASCII letters,
digits, and underscores; names and exit codes must be unique. Declared exit codes occupy 1-63.
Do not reuse built-in names. Category and message are descriptive; message has no placeholders.

Report a named failure with `die NO_INPUT_DATA "details"`. FlowRs records the resolved definition
and passes the step's exit code through. Undeclared process exits can use other codes, so read the
step record to distinguish them from engine failures.

`retryable` defaults to false, which stops retries for that declared error. When true,
`max_retries` overrides the step retry count. Timeouts, signal exits, and missing declared outputs
are not retried.
`help_url` is optional. See [Exit codes](exit-codes.md).

<a id="pipelinehooks--lifecycle-scripts"></a>

### `[pipeline.hooks]` - lifecycle scripts

```toml
[pipeline.hooks]
on_start = ["start.sh"]
on_success = ["success.sh"]
on_failure = ["failure.sh"]
on_error.NO_INPUT_DATA = ["no-input.sh"]
```

Names resolve under `hooks/`. Extensions select interpreters, as for steps. Hooks are
notifications: their failure warns without changing the run outcome.

| Hook | When it starts |
| --- | --- |
| `on_start` | After pipeline loading, before parameter resolution |
| `on_success` | After successful main and teardown work |
| `on_failure` | After failure or handled cancellation, once the lifecycle has started |
| `on_error.CODE` | After a step or detector process fails with that resolved code; excludes cancellation |

Hooks run asynchronously; do not use `on_start` to prepare files required by steps. The invocation
waits for started hooks before reporting its final result; each script has a five-minute timeout.
Early refusals before `on_start`, such as licence failure, do not fire hooks.

`on_start` sees paths but no resolved parameters. `on_success` receives `EXIT_CODE=0`.
`on_failure` receives `EXIT_CODE` when known and `FAILED_STEP` when applicable; cancellation
adds `CANCELLED=1` and `CANCELLED_BY` (signal number). `on_error` receives `ERROR_CODE`.
Outcome variables from other phases are absent.

`on_error` can name declared errors or built-ins such as `TIMEOUT`, `MISSING_OUTPUT`,
`NOT_EXECUTABLE`, `COMMAND_NOT_FOUND`, `UNKNOWN_ERROR`, and signal errors. Hooks receive
`THREADS=1`; keep them lightweight. Logs are under `logs/hooks/`; outcomes appear in
`status.json.lifecycle_hooks`. Process launch failures warn without a record; a missing script
is recorded as skipped. Hook delivery is not guaranteed.

Use a regular step to gate the run or a [teardown step](dependencies.md#teardown-steps) for
delivery work whose failure must fail the run.

### `[pipeline.requires]` - environment notes

```toml
[pipeline.requires]
tools = ["samtools", "bwa"]
python = ["numpy", "pysam"]
r = ["ggplot2"]
```

Requirements install nothing and are not checked by run. Use
`flowrs inspect PIPELINE --check-environment` on the execution machine.
Python entries are import names, not distribution names.

For pipeline directories, ELF checks need `readelf` and `ldconfig` on `PATH`. They check direct
and transitive library presence, not symbols or versions. `$ORIGIN` paths are supported;
`$LIB` and `$PLATFORM` are not expanded.

### `[[constraints]]` - rules across parameters

```toml
[[constraints]]
when = "QUALITY > 50"
require = "MODE == paired"
message = "High quality requires paired mode"
```

Expressions compare a parameter on the left with a literal on the right using
`==`, `!=`, `>`, `<`, `>=`, or `<=`. If `when` is true and `require` is false, resolution fails
at exit 64.

Referenced parameters need defaults in each reachable profile or base configuration.
Invocation-only or detector-only values do not satisfy this compile-time rule.

### `[groups.<name>]` - parameter grouping

```toml
[groups.quality]
description = "Quality filtering"
order = 1
```

`description` is required; `order` defaults to 0. Groups are presentation metadata.
