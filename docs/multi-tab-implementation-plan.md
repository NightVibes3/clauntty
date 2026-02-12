# Multi-Tab SSH Implementation Plan

## Goal

Support multiple terminal sessions with intelligent connection reuse:
- Multiple tabs to same server = 1 SSH connection, N channels
- Multiple tabs to different servers = N SSH connections

## Current Architecture

```
SSHConnection (1 per connection attempt)
  └── Channel (TCP)
        └── SSHChildChannel (PTY session)
              └── SSHChannelHandler (data flow)

AppState
  └── sshConnection: SSHConnection?
  └── currentConnection: SavedConnection?
```

**Limitation:** One session at a time, connection closed when navigating away.

## New Architecture

```
SessionManager (singleton)
  └── ConnectionPool
  │     └── SSHConnection (1 per unique host:port:user)
  │           └── Multiple SSHChildChannels
  │
  └── Sessions: [Session]
        └── Session
              ├── id: UUID
              ├── connection: SavedConnection (config)
              ├── sshChannel: SSHChildChannel
              ├── terminalSurface: TerminalSurfaceView
              └── scrollbackBuffer: Data (for persistence)
```

## Data Models

### Session
```swift
@MainActor
class Session: ObservableObject, Identifiable {
    let id: UUID
    let connectionConfig: SavedConnection

    @Published var state: SessionState // disconnected, connecting, connected, error
    @Published var title: String // "user@host" or custom

    // SSH channel (one per session)
    var sshChannel: Channel?
    var channelHandler: SSHChannelHandler?

    // Terminal (one per session)
    var terminalSurface: TerminalSurfaceView?

    // Scrollback persistence
    var scrollbackBuffer: Data

    func sendData(_ data: Data)
    func sendWindowChange(rows: UInt16, columns: UInt16)
    func disconnect()
}
```

### SessionManager
```swift
@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var activeSessionId: UUID?

    var activeSession: Session? { sessions.first { $0.id == activeSessionId } }

    // Connection pool: key = "user@host:port"
    private var connectionPool: [String: SSHConnection] = []

    func createSession(for connection: SavedConnection) async throws -> Session
    func closeSession(_ session: Session)
    func switchTo(_ session: Session)

    // Connection pooling
    private func getOrCreateConnection(for config: SavedConnection) async throws -> SSHConnection
    private func connectionKey(for config: SavedConnection) -> String
}
```

### Refactored SSHConnection
```swift
@MainActor
class SSHConnection: ObservableObject {
    // ... existing properties ...

    // Track all channels on this connection
    private var channels: [UUID: Channel] = []

    // Create additional channel on existing connection
    func createChannel(sessionId: UUID, onDataReceived: @escaping (Data) -> Void) async throws -> (Channel, SSHChannelHandler)

    // Close specific channel
    func closeChannel(sessionId: UUID)

    // Check if connection is still usable
    var isConnected: Bool { channel?.isActive ?? false }

    // Close entire connection (all channels)
    func disconnect()
}
```

## UI Changes

### Tab Bar Component
```swift
struct SessionTabBar: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(sessionManager.sessions) { session in
                    SessionTab(session: session, isActive: session.id == sessionManager.activeSessionId)
                        .onTapGesture { sessionManager.switchTo(session) }
                }

                // New tab button
                Button(action: { /* show connection picker */ }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct SessionTab: View {
    let session: Session
    let isActive: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(session.state == .connected ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(session.title)
            Button(action: { /* close tab */ }) {
                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}
```

### Updated ContentView Structure
```swift
struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (when sessions exist)
            if !sessionManager.sessions.isEmpty {
                SessionTabBar()
            }

            // Content
            if let activeSession = sessionManager.activeSession {
                TerminalView(session: activeSession)
            } else {
                ConnectionListView()
            }
        }
    }
}
```

## Implementation Steps

### Phase 1: Session Model
- [ ] Create `Session` class
- [ ] Create `SessionManager` class
- [ ] Basic session lifecycle (create, close)
- [ ] Replace `AppState.sshConnection` with `SessionManager`

### Phase 2: Refactor SSHConnection
- [ ] Support multiple channels per connection
- [ ] `createChannel()` method for additional channels
- [ ] `closeChannel()` for individual channel cleanup
- [ ] Reference counting (close connection when last channel closes)

### Phase 3: Connection Pooling
- [ ] `ConnectionPool` with key-based lookup
- [ ] Reuse existing connection for same host:port:user
- [ ] Handle connection failures (remove from pool)
- [ ] Reconnection logic

### Phase 4: Tab UI
- [ ] `SessionTabBar` component
- [ ] Tab switching (swap terminal surfaces)
- [ ] Close tab button
- [ ] New tab button (quick-connect to same server or show picker)

### Phase 5: Scrollback Persistence
- [ ] Buffer SSH output in `Session.scrollbackBuffer`
- [ ] Save to disk on session close
- [ ] Restore on app relaunch
- [ ] Per-session storage keyed by session ID

## Edge Cases

### Connection Drops
- All channels on that connection become invalid
- Mark all affected sessions as disconnected
- Remove connection from pool
- Option to reconnect all sessions

### App Backgrounding
- iOS may kill SSH connections
- Save session state (scrollback) before backgrounding
- On foreground, detect dead connections, offer reconnect

### Same Server, Different Credentials
- Connection key includes username: `user@host:port`
- Different users = different connections (correct behavior)

### Tab Limits
- Consider max tabs (memory usage for terminal surfaces)
- Maybe 10-20 tabs max?

## File Changes Summary

| File | Change |
|------|--------|
| `Session.swift` | NEW - Session model |
| `SessionManager.swift` | NEW - Manages sessions + connection pool |
| `SSHConnection.swift` | MODIFY - Support multiple channels |
| `ContentView.swift` | MODIFY - Add tab bar, use SessionManager |
| `TerminalView.swift` | MODIFY - Accept Session instead of AppState |
| `ConnectionListView.swift` | MODIFY - Create session via SessionManager |
| `SessionTabBar.swift` | NEW - Tab bar UI |
| `AppState.swift` | MODIFY - Remove SSH state (moved to SessionManager) |
