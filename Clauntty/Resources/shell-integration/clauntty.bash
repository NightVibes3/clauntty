# Clauntty Shell Integration for Bash
# Emits OSC 133 sequences for terminal prompt detection
#
# This enables Clauntty to detect when the shell is waiting for input,
# allowing notifications when background tabs need attention.

# Only run in interactive mode
[[ "$-" != *i* ]] && return

# Avoid double-sourcing
[[ -n "$CLAUNTTY_SHELL_INTEGRATION" ]] && return
export CLAUNTTY_SHELL_INTEGRATION=1

# We need bash-preexec for preexec/precmd hooks
# Inline a minimal version if not already loaded
if ! declare -F __bp_precmd_invoke_cmd >/dev/null 2>&1; then
    # Minimal bash-preexec implementation
    __clauntty_preexec_functions=()
    __clauntty_precmd_functions=()

    __clauntty_run_precmd() {
        local f
        for f in "${__clauntty_precmd_functions[@]}"; do
            "$f"
        done
    }

    __clauntty_run_preexec() {
        local f
        for f in "${__clauntty_preexec_functions[@]}"; do
            "$f" "$1"
        done
    }

    # Use DEBUG trap for preexec
    __clauntty_preexec_trap() {
        [[ -n "$COMP_LINE" ]] && return  # Skip during completion
        [[ "$BASH_COMMAND" == "$PROMPT_COMMAND" ]] && return  # Skip prompt command
        __clauntty_run_preexec "$BASH_COMMAND"
    }

    trap '__clauntty_preexec_trap' DEBUG

    # Add precmd to PROMPT_COMMAND
    PROMPT_COMMAND="__clauntty_run_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

    # Aliases for compatibility
    preexec_functions=("${__clauntty_preexec_functions[@]}")
    precmd_functions=("${__clauntty_precmd_functions[@]}")
fi

# Track execution state
_clauntty_executing=""
_clauntty_last_status=0

# Called before each prompt is displayed
__clauntty_precmd() {
    _clauntty_last_status=$?

    if [[ -n "$_clauntty_executing" ]]; then
        # End of command output, report exit status
        # OSC 133;D - Command finished
        builtin printf '\e]133;D;%s\a' "$_clauntty_last_status"
    fi

    # OSC 133;A - Prompt start (shell waiting for input)
    builtin printf '\e]133;A\a'
    _clauntty_executing=""
}

# Called just before a command is executed
__clauntty_preexec() {
    # OSC 133;C - Command starting (output begins)
    builtin printf '\e]133;C\a'
    _clauntty_executing=1
}

# Register our hooks
if declare -F __bp_precmd_invoke_cmd >/dev/null 2>&1; then
    # bash-preexec is available
    precmd_functions+=(__clauntty_precmd)
    preexec_functions+=(__clauntty_preexec)
else
    # Use our minimal implementation
    __clauntty_precmd_functions+=(__clauntty_precmd)
    __clauntty_preexec_functions+=(__clauntty_preexec)
fi
