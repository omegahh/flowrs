# Print an optspec for argparse to handle cmd's options that are independent of any subcommand.
function __fish_flowrs_global_optspecs
    string join \n q/quiet v/verbose h/help V/version
end

function __fish_flowrs_needs_command
    # Figure out if the current invocation already has a command.
    set -l cmd (commandline -opc)
    set -e cmd[1]
    argparse -s (__fish_flowrs_global_optspecs) -- $cmd 2>/dev/null
    or return
    if set -q argv[1]
        # Also print the command, so this can be used to figure out what it is.
        echo $argv[1]
        return 1
    end
    return 0
end

function __fish_flowrs_using_subcommand
    set -l cmd (__fish_flowrs_needs_command)
    test -z "$cmd"
    and return 1
    contains -- $cmd[1] $argv
end

complete -c flowrs -n "__fish_flowrs_needs_command" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_needs_command" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_needs_command" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_needs_command" -s V -l version -d 'Print version'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "run" -d 'Execute a pipeline'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "create" -d 'Scaffold a new pipeline in a directory of its own'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "compile" -d 'Validate a pipeline, optionally packaging it into a .flowpkg'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "registry" -d 'Add, remove, and list named pipelines'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "inspect" -d 'Show a pipeline\'s steps, parameters, constraints, errors, and hooks'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "license" -d 'Inspect, install, and report on licenses'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s i -l input-dir -d 'Input data, read-only: the engine never writes here' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s w -l work-dir -d 'Everything the run writes goes here' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s t -l task-id -d 'Name the run, putting its outputs in WORK_DIR/TASKID/' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s c -l config -d 'Load parameters from a JSON, TOML, or KEY=VALUE file' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s p -l param -d 'Set one parameter, overriding -c (repeatable)' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s @ -l threads -d 'Total threads shared by all concurrent work' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s s -l start-step -d 'Start here, dropping everything upstream' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s e -l end-step -d 'Stop here, dropping everything downstream' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s k -l skip-steps -d 'Skip these steps, keeping the rest of the graph' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l max-in-flight -d 'Cap how many items of a scattered step run at once' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l tmp-dir -d 'Put temporary files here instead of OUT_DIR/tmp' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l resume -d 'Continue a prior run, skipping steps that already completed'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l force -d 'Allow a --resume override that a completed step\'s cache key covers'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l keep-tmp -d 'Keep temporary files after the run finishes'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s d -l description -d 'Description written into the new manifest' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -l update -d 'Refresh the scaffold files in an existing pipeline'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -s o -l output -d 'Bundle the pipeline into this .flowpkg file' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -l sign-with -d 'Sign the package with this RSA private key (PEM)' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -l author -d 'Record this author in the package metadata' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -l encrypt -d 'Protect the payloads, so running needs a valid license and matching grant'
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -l json -d 'Emit the diagnostics envelope as JSON on stdout'
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -f -a "add" -d 'Register a pipeline under a name for `flowrs run`'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -f -a "remove" -d 'Remove a pipeline from the registry'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -f -a "list" -d 'List registered pipelines'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and not __fish_seen_subcommand_from add remove list help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from add" -l name -d 'Register under this name instead of one derived from the path' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from add" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from add" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from add" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from remove" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from remove" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from remove" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from list" -s d -l detailed -d 'Also show each full file path and whether it still exists'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from list" -l json -d 'Emit JSON on stdout instead of human-readable text'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from list" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from list" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from list" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from help" -f -a "add" -d 'Register a pipeline under a name for `flowrs run`'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from help" -f -a "remove" -d 'Remove a pipeline from the registry'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from help" -f -a "list" -d 'List registered pipelines'
complete -c flowrs -n "__fish_flowrs_using_subcommand registry; and __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand inspect" -l check-environment -d 'Check host tools and packages instead of showing the manifest'
complete -c flowrs -n "__fish_flowrs_using_subcommand inspect" -l json -d 'Emit JSON on stdout instead of human-readable text'
complete -c flowrs -n "__fish_flowrs_using_subcommand inspect" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand inspect" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand inspect" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -f -a "status" -d 'Show the active license and verify its signature'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -f -a "add" -d 'Install a license file to the default location'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -f -a "fingerprint" -d 'Print this machine\'s fingerprint, for requesting a license'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and not __fish_seen_subcommand_from status add fingerprint help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from status" -s f -l file -d 'Check this license file instead of searching the default paths' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from status" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from status" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from status" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from add" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from add" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from add" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from fingerprint" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from fingerprint" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from fingerprint" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from help" -f -a "status" -d 'Show the active license and verify its signature'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from help" -f -a "add" -d 'Install a license file to the default location'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from help" -f -a "fingerprint" -d 'Print this machine\'s fingerprint, for requesting a license'
complete -c flowrs -n "__fish_flowrs_using_subcommand license; and __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "run" -d 'Execute a pipeline'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "create" -d 'Scaffold a new pipeline in a directory of its own'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "compile" -d 'Validate a pipeline, optionally packaging it into a .flowpkg'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "registry" -d 'Add, remove, and list named pipelines'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "inspect" -d 'Show a pipeline\'s steps, parameters, constraints, errors, and hooks'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "license" -d 'Inspect, install, and report on licenses'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect license help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from registry" -f -a "add" -d 'Register a pipeline under a name for `flowrs run`'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from registry" -f -a "remove" -d 'Remove a pipeline from the registry'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from registry" -f -a "list" -d 'List registered pipelines'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from license" -f -a "status" -d 'Show the active license and verify its signature'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from license" -f -a "add" -d 'Install a license file to the default location'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from license" -f -a "fingerprint" -d 'Print this machine\'s fingerprint, for requesting a license'
