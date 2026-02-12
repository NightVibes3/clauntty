# Session Persistence Brainstorm

Future feature exploration for maintaining terminal state across disconnects.

## The Problem

When SSH disconnects (network drop, app backgrounded, etc.):
- Shell process dies on remote server
- All running processes killed (vim, npm dev server, Claude Code, etc.)
- Terminal state lost

This is inherent to how terminals work - state lives in running processes, not in the connection.

## Options Explored

### 1. Local Scrollback Persistence (Recommended - Phase 1)

**How it works:**
- Buffer all SSH output locally as it arrives
- On disconnect → save buffer to disk
- On reconnect → replay buffer to new terminal surface

**Pros:**
- Simple to implement
- No server-side requirements
- Visual history preserved (commands, outputs, colors)

**Cons:**
- Processes don't survive (new shell on reconnect)
- Can't resume running commands

**Good for Claude Code:** Most usage is command → output → next command. The output history is the valuable part.

### 2. tmux Auto-Wrapper (NOT Recommended)

**Why rejected:**
- Claude Code's renderer + tmux = rendering artifacts
- tmux does double terminal emulation (program → tmux → terminal)
- This was the primary motivation for building Clauntty with native Ghostty

### 3. dtach Integration (Recommended - Phase 2)

**What is dtach:**
- Minimal detach-only tool (~1,000 lines vs tmux's 70,000+)
- Just proxies bytes, no terminal emulation
- Keeps PTY alive when disconnected

**How it differs from tmux:**
| Feature | dtach | tmux |
|---------|-------|------|
| Detach/attach | ✓ | ✓ |
| Windows/panes | ✗ | ✓ |
| Status bar | ✗ | ✓ |
| Terminal emulation | ✗ | ✓ |
| Rendering overhead | None | Significant |

**Proposed implementation:**
```
# First connect
SSH → dtach -A ~/.clauntty/{session-id} $SHELL

# Reconnect (session exists)
SSH → dtach -a ~/.clauntty/{session-id}

# Reconnect (session gone)
SSH → dtach -A ~/.clauntty/{session-id} $SHELL
```

**User experience:**
- Transparent - user doesn't know dtach is there
- Disconnect → processes keep running
- Reconnect → back exactly where you left off

**Challenges:**
- dtach must be installed on server
- Need to detect availability, fall back gracefully
- Session cleanup (stale sockets)

**TODO:** Test Claude Code rendering through dtach to confirm no artifacts.

```bash
# Test command
brew install dtach
dtach -A /tmp/test-session -z claude
# Use Claude Code, check for rendering issues
# Detach: Ctrl+\
# Reattach: dtach -a /tmp/test-session
```

### 4. Native Claude Code Client (Out of Scope)

**Idea:** Build native iOS Claude Code client that uses SSH only for command execution.

**Why not:**
- Native UIs always lag behind CLI features
- Claude Code team constantly adds new features
- Zed already has this (see ~/zed-claude-code-integration.md)
- Claude Code is closed source, can't add daemon mode ourselves

### 5. Aggressive Connection Persistence

**Complement to other approaches:**
- SSH keepalives
- iOS background modes
- Automatic reconnection on network change
- Reduce disconnects rather than recover from them

## Implementation Plan

### Phase 1: Local Scrollback (with multi-tab)
- [ ] Buffer SSH output in memory
- [ ] Persist to disk on disconnect
- [ ] Restore to new terminal surface on reconnect
- [ ] Per-session storage (each tab has its own buffer)

### Phase 2: dtach Integration
- [ ] Test dtach with Claude Code (confirm no rendering issues)
- [ ] Detect dtach availability on first connect
- [ ] Auto-wrap sessions in dtach when available
- [ ] Session management (naming, cleanup)
- [ ] Graceful fallback when dtach unavailable
- [ ] User preference: enable/disable dtach persistence

### Phase 3: Connection Resilience
- [ ] Aggressive keepalives
- [ ] iOS background mode exploration
- [ ] Auto-reconnect logic
- [ ] Visual indicator of connection state

## References

- dtach: https://github.com/crigler/dtach
- tmux rendering issues: Internal observation with Claude Code
- Zed Claude Code integration: ~/zed-claude-code-integration.md
