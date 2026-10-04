# Manifest Contract

Read assets/manifest-v1.json for field names and value shapes. Validate semantic constraints with
flowrs compile --json. Use only the fields listed here. Unknown fields are rejected.

## Top Level

| TOML table | Required fields | Allowed fields |
| --- | --- | --- |
| [pipeline] | name, version | author, cache_dir, description, detector_timeout, hooks, license, min_threads, requires |
| [steps.NAME] | exec, label | cache, cache_key, depends_on, gather, outputs, retries, retry_delay, scatter, teardown, threads, threads_weight, timeout, trigger_rule |
| [defaults] | none | retries, retry_delay, timeout |
| [params.NAME] | type | default, description, detector, enum, exclusive_max, exclusive_min, group, increment, max, min, profiles, readonly, profile override tables |
| [[errors]] | code, exit_code, category, message | help_url, max_retries, retryable |
| [collections.NAME] | source, id_column | format |
| [[constraints]] | when, require, message | none |
| [groups.NAME] | description | order |

Pipeline and step names are identifiers used in paths and graph keys. Reject empty names, path
separators, and double-dot. Keep exec, detector, and hook values as one filename without a separator.

## Pipeline

~~~toml
[pipeline]
name = "rnaseq"
version = "1.2.0"
description = "RNA-seq quantification"
author = "Team"
license = "internal"
min_threads = 4
cache_dir = "shared"
detector_timeout = 60
~~~

- name and version are strings and are required.
- cache_dir is one relative path segment under the work directory. Declare it when any step has
  cache = true.
- detector_timeout is seconds per detector; default 60.
- min_threads is the minimum run budget; it is an optional non-negative integer.
- description, author, and license are metadata.
- [pipeline.requires] is advisory and does not install or check anything during run.

## Steps

~~~toml
[steps.align]
exec = "align.sh"
label = "Align reads"
depends_on = ["trim"]
threads = "auto"
threads_weight = 2
timeout = 3600
retries = 2
retry_delay = 30
trigger_rule = "all_success"
outputs = ["${OUT_DIR}/aligned.bam"]
cache = false
cache_key = ["reference"]
teardown = false
~~~

- exec names a file under steps/; label is required and is shown in output and status.json.
- depends_on is a list of declared step names. It creates graph edges.
- threads is "auto" or an integer of at least 1. Omit it to use the step default.
- threads_weight is a positive integer for an auto step; omit it for weight 1. Reject it with a
  fixed threads value.
- timeout, retries, and retry_delay are non-negative integer seconds/counts. Retries are
  bounded by the engine's maximum of 10; step values override [defaults].
- trigger_rule defaults to all_success. Accepted values are all_success, all_failed, all_done,
  one_success, one_failed, none_failed, none_failed_min_one_success, none_skipped, and always.
- outputs is optional. Scalar outputs may use ${OUT_DIR}, ${WORK_DIR}, ${TMP_DIR}, or absolute
  paths; writing below ${CACHE_DIR} requires cache = true. Scattered outputs use ${ITEM_DIR},
  including when cached. ${INPUT_DIR} is forbidden, and a scalar step has no ${ITEM_DIR}.
  A declared output missing after exit 0 changes the step result to exit 120.
- teardown = true runs the step after the main graph, whether the graph succeeds or fails. It is
  not allowed with scatter.
- gather is a list of scattered step names. It waits for every instance as one batch and provides
  FLOWRS_GATHER_MANIFEST. Do not repeat a gathered step in depends_on or combine gather with scatter.
- scatter is a collection name or { collection = "NAME" }. It runs once per collection item.
- cache = true requires pipeline.cache_dir. Declare every file written below ${CACHE_DIR} in
  outputs; declare the parameter names that affect the output in cache_key. Do not name a
  readonly parameter in cache_key.

## Defaults

~~~toml
[defaults]
retries = 1
retry_delay = 5
timeout = 600
~~~

Apply these to every step that does not set the corresponding value. No other default field is
valid.

## Parameters

~~~toml
[params.quality]
type = "integer"
default = 20
description = "Minimum base quality"
min = 0
max = 60
exclusive_min = 0
exclusive_max = 100
increment = 5
group = "quality"
readonly = false
enum = [10, 20, 30]
detector = "detect_quality.sh"
~~~

- type is required and is one of integer, number, string, or boolean.
- default is the base fallback. Without one, a detector, profile default, or resume baseline can
  still supply the value. Require -p or -c only when no other tier supplies it; there is no
  required = true field.
- description is display text. group is UI metadata and must name an existing [groups.NAME].
- min and max are inclusive numeric bounds. exclusive_min and exclusive_max are strict numeric
  bounds. increment applies only to integer and number params, and values must be spaced by it
  from min when present, or zero otherwise.
- enum restricts values to a typed list. Values are coerced to the declared type before checking.
- readonly = true refuses every -p and -c override. A readonly parameter needs a default or a
  profile default.
- detector names one file under bin/. A detector and readonly cannot be combined. A detector
  inside a profile override is invalid.

Resolve values in this order, highest first:

~~~text
readonly gate > -p/-c > detected > profile default > base default > unset
~~~

On resume, recorded values sit below explicit overrides and above detection. Readonly parameters
refuse explicit overrides and resolve from the current manifest's defaults, ignoring the recorded
value. A readonly parameter cannot have a detector. A value at unset makes the run fail with exit
64 and names every missing parameter.

### Profiles

When profiles are needed, put them on at most one parameter. Give string and numeric selectors an
enum; a boolean selector already has the closed domain true and false.

~~~toml
[params.read_type]
type = "string"
enum = ["single", "paired"]

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
~~~

Profile member values must partition the whole domain exactly once. Arrays list individual values,
including for numeric selectors: [100, 150] means those two values, not an interval. A profile
override may set only default, min, max, exclusive_min, exclusive_max, and increment.

Do not put a profile override on the parameter that selects the profile or on a parameter with a
detector. Resolve the selector first, then apply the selected defaults to the other parameters.

## Errors

~~~toml
[[errors]]
code = "NO_INPUT_DATA"
exit_code = 20
category = "input"
message = "No input data found"
retryable = false
max_retries = 0
help_url = "https://example.invalid/no-input"
~~~

- code is non-empty and uses only A-Z, 0-9, and underscore; it must be unique and cannot be an
  engine built-in name.
- exit_code must be unique and in 1..=63.
- category is a free-form label.
- message is static text; do not add runtime placeholders.
- retryable defaults to false; max_retries overrides the step retry count for this code.
- help_url is optional.

Report an error from a script by its code, not its number. A matching on_error.CODE hook may
react to it.

## Hooks

~~~toml
[pipeline.hooks]
on_start = ["announce.sh"]
on_success = ["publish.sh"]
on_failure = ["notify.sh"]
on_error.NO_INPUT_DATA = ["repair-input.sh"]
~~~

Use bare filenames resolved under hooks/. Accepted keys are on_start, on_success, on_failure,
and on_error.CODE. Hooks are side-channel notifications: they do not participate in the DAG,
slices, or thread budget, and a hook failure never fails the run. Cancellation does not trigger a
new on_error hook. Use a teardown step for delivery work whose failure must fail the run.

## Collections

~~~toml
[collections.samples]
source = "${INPUT_DIR}/samples.tsv"
id_column = "sample_id"
format = "tsv"
~~~

format is tsv, json, or omitted to infer from the file extension. TSV has a header row and
tab-separated records. JSON is an array of objects. id_column is the TSV column or JSON key that
holds each item id. Collection names are single path components. Item ids are data values and are
encoded by the engine before reaching a path.

Use an absolute source or a path relative to INPUT_DIR. Only a leading `${INPUT_DIR}` expands;
other variables are refused during manifest validation.

Scatter a step with scatter = "samples". Every item receives ITEM_DIR, item index, id, and a
metadata file. Launch order is collection-file order. A gather step names scattered steps in
gather = ["align"] and waits for every instance.

## Constraints

~~~toml
[[constraints]]
when = "QUALITY > 50"
require = "MODE == paired"
message = "High quality requires paired mode"
~~~

Use one comparison per expression. Supported operators are ==, !=, >, <, >=, and <=. The left
side of when and require names a parameter; the right side is a literal. When when is true and
require is false, resolution fails with exit 64.

## Requirements And Groups

~~~toml
[pipeline.requires]
tools = ["samtools", "bwa"]
python = ["numpy", "pysam"]
r = ["ggplot2"]

[groups.quality]
description = "Quality filtering"
order = 1
~~~

Requirements are advisory and are checked only by flowrs inspect --check-environment. Groups are
UI organization metadata. order defaults to 0.

## Complete Example

~~~toml
[pipeline]
name = "sample-qc"
version = "1.0.0"
description = "Check and summarize sample files"
min_threads = 2

[pipeline.hooks]
on_failure = ["notify.sh"]

[pipeline.requires]
tools = ["samtools"]

[collections.samples]
source = "${INPUT_DIR}/samples.tsv"
id_column = "sample"
format = "tsv"

[params.min_quality]
type = "integer"
default = 20
min = 0
max = 60

[[errors]]
code = "NO_READS"
exit_code = 20
category = "input"
message = "No reads found"

[steps.align]
exec = "align.sh"
label = "Align samples"
scatter = "samples"
threads = "auto"
outputs = ["${ITEM_DIR}/aligned.bam"]

[steps.summarize]
exec = "summarize.sh"
label = "Summarize alignments"
gather = ["align"]
threads = 1
outputs = ["${OUT_DIR}/summary.tsv"]
~~~
