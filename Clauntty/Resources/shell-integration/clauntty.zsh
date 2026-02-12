# Clauntty Shell Integration for Zsh
# Emits OSC 133 sequences for terminal prompt detection
#
# This enables Clauntty to detect when the shell is waiting for input,
# allowing notifications when background tabs need attention.

# Only run in interactive mode
[[ -o interactive ]] || return

# Avoid double-sourcing
[[ -n "$CLAUNTTY_SHELL_INTEGRATION" ]] && return
export CLAUNTTY_SHELL_INTEGRATION=1

# Track execution state
typeset -g _clauntty_executing=""

# Called before each prompt is displayed
__clauntty_precmd() {
    local ret=$?

    if [[ -n "$_clauntty_executing" ]]; then
        # End of command output, report exit status
        # OSC 133;D - Command finished
        print -n "\e]133;D;${ret}\a"
    fi

    # OSC 133;A - Prompt start (shell waiting for input)
    print -n "\e]133;A\a"
    _clauntty_executing=""
}

# Called just before a command is executed
__clauntty_preexec() {
    # OSC 133;C - Command starting (output begins)
    print -n "\e]133;C\a"
    _clauntty_executing=1
}

# Register hooks using zsh's built-in arrays
autoload -Uz add-zsh-hook
add-zsh-hook precmd __clauntty_precmd
add-zsh-hook preexec __clauntty_preexec
