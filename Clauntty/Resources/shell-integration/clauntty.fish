# Clauntty Shell Integration for Fish
# Emits OSC 133 sequences for terminal prompt detection
#
# This enables Clauntty to detect when the shell is waiting for input,
# allowing notifications when background tabs need attention.

# Only run in interactive mode
status is-interactive; or exit

# Avoid double-sourcing
if set -q CLAUNTTY_SHELL_INTEGRATION
    exit
end
set -gx CLAUNTTY_SHELL_INTEGRATION 1

# Track execution state
set -g _clauntty_executing ""

# Called before each prompt is displayed
function __clauntty_prompt --on-event fish_prompt
    set -l last_status $status

    if test -n "$_clauntty_executing"
        # End of command output, report exit status
        # OSC 133;D - Command finished
        printf '\e]133;D;%s\a' $last_status
    end

    # OSC 133;A - Prompt start (shell waiting for input)
    printf '\e]133;A\a'
    set -g _clauntty_executing ""
end

# Called just before a command is executed
function __clauntty_preexec --on-event fish_preexec
    # OSC 133;C - Command starting (output begins)
    printf '\e]133;C\a'
    set -g _clauntty_executing 1
end
