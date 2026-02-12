# rtach Protocol Upgrade: Framed Client Input

## Problem

The iOS client sends mixed data to rtach:
- **Keyboard input**: sent RAW (unframed)
- **Control messages** (scrollback requests): sent FRAMED `[type, len, payload]`

rtach's `PacketReader` tries to parse ALL input as framed packets, causing corruption when raw keyboard data is misinterpreted as packet headers.

**Example**: Raw "hello" is parsed as:
- Header: type='h'(104), len='e'(101)
- Waits for 101 bytes of payload, corrupting subsequent input

**Symptom**: "@" character appears when scrolling (from scrollback request's limit field 0x4000 containing 0x40='@')

---

## Solution: Protocol Upgrade (like HTTP Upgrade)

### Design

1. **rtach starts in RAW mode**: All client input forwarded directly to PTY
2. **Client receives handshake**: Confirms rtach is running
3. **Client sends UPGRADE packet**: Signals switch to framed mode
4. **rtach switches to FRAMED mode**: Now parses all input as packets
5. **Client frames all subsequent data**: Keyboard as push packets `[0, len, data]`

### Benefits

- **Backwards compatible**: Early typing before handshake still works
- **No race conditions**: Raw input before upgrade is handled correctly
- **Clean separation**: Raw mode for legacy/simple, framed mode for full features
- **Low overhead**: 2 bytes per packet (negligible vs SSH overhead)

---

## Protocol Changes

### New MessageType (client → rtach)

```zig
pub const MessageType = enum(u8) {
    push = 0,
    attach = 1,
    detach = 2,
    winch = 3,
    redraw = 4,
    request_scrollback = 5,
    request_scrollback_page = 6,
    upgrade = 7,  // NEW: Switch to framed mode
};
```

### Upgrade Packet Format

```
[type: 1 byte = 7][len: 1 byte = 0]
```

No payload needed - just signals the mode switch.

### Push Packet Format (keyboard input when framed)

```
[type: 1 byte = 0][len: 1 byte][payload: len bytes]
```

Max 255 bytes per packet. Larger input split across multiple packets.

---

## Implementation Plan

### Phase 1: Swift Protocol Module (new)

Create `RtachClient` Swift package for rtach protocol handling:

```
clauntty/
├── RtachClient/                # NEW: Pure Swift protocol module
│   ├── Package.swift
│   ├── Sources/
│   │   └── RtachClient/
│   │       ├── Protocol.swift           # Message types, constants
│   │       ├── PacketReader.swift       # Frame parser state machine
│   │       ├── PacketWriter.swift       # Frame encoder
│   │       └── RtachSession.swift       # State machine (raw/framed mode)
│   └── Tests/
│       └── RtachClientTests/
│           ├── PacketReaderTests.swift
│           ├── PacketWriterTests.swift
│           ├── RtachSessionTests.swift
│           └── ProtocolUpgradeTests.swift
```

**Key types:**

```swift
// RtachProtocol.swift
public enum MessageType: UInt8 {
    case push = 0
    case attach = 1
    case detach = 2
    case winch = 3
    case redraw = 4
    case requestScrollback = 5
    case requestScrollbackPage = 6
    case upgrade = 7
}

public enum ResponseType: UInt8 {
    case terminalData = 0
    case scrollback = 1
    case command = 2
    case scrollbackPage = 3
    case handshake = 255
}

// PacketWriter.swift
public struct PacketWriter {
    public static func push(_ data: Data) -> Data
    public static func upgrade() -> Data
    public static func scrollbackRequest(offset: UInt32, limit: UInt32) -> Data
    public static func winch(rows: UInt16, cols: UInt16) -> Data
}
```

### Phase 2: rtach Changes

**File: `/Users/eriklangille/Projects/clauntty/rtach/src/protocol.zig`**

1. Add `upgrade = 7` to MessageType enum

**File: `/Users/eriklangille/Projects/clauntty/rtach/src/master.zig`**

1. Add `framed_mode: bool = false` to ClientConn struct
2. Modify `clientReadCallback`:
   - If `!framed_mode`: forward all input directly to PTY
   - If `framed_mode`: parse packets via PacketReader
3. Add `.upgrade` handler in `handleClientPacket`:
   - Set `client.framed_mode = true`
   - Log mode switch

**New tests in rtach:**

```zig
// tests/protocol_upgrade_test.zig
test "raw mode forwards input to PTY" { ... }
test "upgrade packet switches to framed mode" { ... }
test "framed mode parses push packets" { ... }
test "framed mode handles scrollback request" { ... }
test "mixed raw then framed works correctly" { ... }
```

### Phase 3: Swift Integration

**File: `Session.swift`**

1. After receiving handshake, send upgrade packet
2. Track `isFramedMode: Bool`
3. In `sendData()`:
   - If `isFramedMode`: wrap in push packet
   - Else: send raw

```swift
private var isFramedMode = false

private func handleHandshake(_ data: Data) {
    // ... existing handshake parsing ...

    // Send upgrade packet to switch rtach to framed mode
    let upgradePacket = PacketWriter.upgrade()
    channelHandler?.sendToRemote(upgradePacket)
    isFramedMode = true

    Logger.clauntty.info("Sent upgrade packet, switching to framed mode")
}

func sendData(_ data: Data) {
    if isFramedMode {
        // Frame as push packet(s)
        var offset = 0
        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + 255, data.count))
            let packet = PacketWriter.push(chunk)
            channelHandler?.sendToRemote(packet)
            offset += chunk.count
        }
    } else {
        // Raw mode - send directly
        channelHandler?.sendToRemote(data)
    }
}
```

### Phase 4: Testing

**rtach tests (Zig):**
```bash
cd rtach && zig build test
```

**Swift protocol tests:**
```bash
cd clauntty/RtachClient && swift test
```

**Integration tests (bun):**
```bash
cd rtach/tests && bun test
```

**Simulator tests:**
```bash
./scripts/sim.sh debug devbox
# Scroll, type, verify no "@" appears
```

---

## Test Cases

### rtach Unit Tests

1. **Raw mode input forwarding**
   - Send raw "hello" before upgrade
   - Verify PTY receives "hello"

2. **Upgrade packet handling**
   - Send upgrade packet `[7, 0]`
   - Verify client switches to framed mode

3. **Framed push packet**
   - After upgrade, send `[0, 5, h, e, l, l, o]`
   - Verify PTY receives "hello"

4. **Framed scrollback request**
   - After upgrade, send scrollback request
   - Verify scrollback response (not forwarded to PTY)

5. **Mixed mode transition**
   - Send raw "abc"
   - Send upgrade
   - Send framed "def"
   - Verify PTY receives "abcdef"

### Swift Unit Tests

1. **PacketWriter.push()**
   - Single byte → `[0, 1, byte]`
   - 255 bytes → `[0, 255, ...]`
   - Empty → `[0, 0]`

2. **PacketWriter.upgrade()**
   - Returns `[7, 0]`

3. **PacketWriter.scrollbackRequest()**
   - offset=0, limit=16384 → `[6, 8, 0,0,0,0, 0,64,0,0]`

4. **Large input splitting**
   - 300 bytes → two packets: 255 + 45 bytes

### Integration Tests

1. **Connect without rtach**
   - Verify typing works (raw mode)
   - Verify scrollback request blocked (no handshake)

2. **Connect with rtach**
   - Verify handshake received
   - Verify upgrade sent
   - Verify typing works (framed mode)
   - Verify scrollback request works
   - Verify no "@" on scroll

---

## Rollout

1. Deploy updated rtach to servers (backwards compatible - starts in raw mode)
2. Update iOS app with protocol module
3. Test on simulator
4. Test on device

---

## I/O Architecture

**Current data flow (iOS client):**

```
Network socket
    ↓
kqueue (via SwiftNIO EventLoopGroup)
    ↓
SwiftNIO reads from socket
    ↓
NIO SSH decrypts data
    ↓
SSHChannelHandler.channelRead() [NIO thread]
    ↓
DispatchQueue.main.async
    ↓
Session.handleDataReceived() [main thread]
    ↓
RtachClient.process() [parse frames]
    ↓
Terminal display / scrollback handling
```

**Key points:**
- SwiftNIO uses **kqueue** on Darwin (macOS/iOS) for efficient event-driven I/O
- Single-threaded event loop: `MultiThreadedEventLoopGroup(numberOfThreads: 1)`
- Data hops to main thread via `DispatchQueue.main.async` (required for UI)
- RtachClient module handles protocol parsing, independent of I/O layer

---

## Future Considerations

- **Protocol version negotiation**: Handshake already includes version
- **Compression**: Could add compressed push packets for large pastes
- **Binary data**: Current 255-byte limit may need extension for file transfers
