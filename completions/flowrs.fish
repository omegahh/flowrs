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
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "compile" -d 'Validate a pipeline and optionally create a plaintext .flowpkg'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "registry" -d 'Add, remove, and list named pipelines'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "inspect" -d 'Show a pipeline\'s steps, parameters, constraints, errors, and hooks'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "identity" -d 'Create or inspect the customer proof-of-possession identity'
complete -c flowrs -n "__fish_flowrs_needs_command" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s i -l input-dir -d 'Input directory' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s w -l work-dir -d 'Results and shared cache directory' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s t -l task-id -d 'Run ID; outputs under WORK_DIR/ID' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s c -l config -d 'Parameters from JSON, TOML, or KEY=VALUE' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s p -l param -d 'Set a parameter (repeatable; overrides -c)' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s @ -l threads -d 'Thread budget (default: min_threads or CPU count)' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s s -l start-step -d 'Start at STEP, excluding upstream steps' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s e -l end-step -d 'Stop at STEP, excluding downstream steps' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s k -l skip-steps -d 'Skip the listed steps' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l max-in-flight -d 'Concurrent items per scatter step (within -@)' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l tmp-dir -d 'Temporary directory (default: OUT_DIR/tmp)' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l resume -d 'Skip completed steps (conflicts with -s/-e/-k)'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l force -d 'With --resume, reuse results after input/cache-key changes'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -l keep-tmp -d 'Keep temporary files after the run'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand run" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s d -l description -d 'Description written into the new manifest' -r
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -l update -d 'Refresh the scaffold files in an existing pipeline'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand create" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -s o -l output -d 'Bundle the pipeline into this .flowpkg file' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand compile" -l author -d 'Record this author in the package metadata' -r
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
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and not __fish_seen_subcommand_from init show help" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and not __fish_seen_subcommand_from init show help" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and not __fish_seen_subcommand_from init show help" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and not __fish_seen_subcommand_from init show help" -f -a "init" -d 'Create a customer Ed25519 identity'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and not __fish_seen_subcommand_from init show help" -f -a "show" -d 'Print the public key for server registration'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and not __fish_seen_subcommand_from init show help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from init" -s o -l output -d 'Write the private identity key to this file instead of ~/.flowrs/identity.pem' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from init" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from init" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from init" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from show" -l identity -d 'Identity private key; defaults to FLOWRS_IDENTITY or ~/.flowrs/identity.pem' -r -F
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from show" -l json -d 'Emit the public identity record as JSON'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from show" -s q -l quiet -d 'Suppress all output except errors'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from show" -s v -l verbose -d 'Print per-step detail; repeat for more (-vv); -q wins'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from show" -s h -l help -d 'Print help'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from help" -f -a "init" -d 'Create a customer Ed25519 identity'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from help" -f -a "show" -d 'Print the public key for server registration'
complete -c flowrs -n "__fish_flowrs_using_subcommand identity; and __fish_seen_subcommand_from help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "run" -d 'Execute a pipeline'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "create" -d 'Scaffold a new pipeline in a directory of its own'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "compile" -d 'Validate a pipeline and optionally create a plaintext .flowpkg'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "registry" -d 'Add, remove, and list named pipelines'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "inspect" -d 'Show a pipeline\'s steps, parameters, constraints, errors, and hooks'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "identity" -d 'Create or inspect the customer proof-of-possession identity'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and not __fish_seen_subcommand_from run create compile registry inspect identity help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from registry" -f -a "add" -d 'Register a pipeline under a name for `flowrs run`'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from registry" -f -a "remove" -d 'Remove a pipeline from the registry'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from registry" -f -a "list" -d 'List registered pipelines'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from identity" -f -a "init" -d 'Create a customer Ed25519 identity'
complete -c flowrs -n "__fish_flowrs_using_subcommand help; and __fish_seen_subcommand_from identity" -f -a "show" -d 'Print the public key for server registration'
