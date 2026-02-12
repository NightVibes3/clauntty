import Foundation

/// Bridge between local PTY and SSH channel
/// Creates a local PTY pair that Ghostty attaches to, then bridges
/// the PTY master to the SSH channel for remote I/O.
class GhosttyBridge {
    // MARK: - PTY File Descriptors

    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var slavePath: String = ""

    // MARK: - State

    private var isRunning = false
    private var readQueue: DispatchQueue?
    private var readSource: DispatchSourceRead?

    // Callback for data received from PTY (to send to SSH)
    var onDataFromTerminal: ((Data) -> Void)?

    // MARK: - Initialization

    init() {}

    deinit {
        stop()
    }

    // MARK: - PTY Management

    /// Create a PTY pair for bridging
    /// Returns the slave path that Ghostty should use
    func start() throws -> String {
        // Open the PTY master
        masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFD >= 0 else {
            throw BridgeError.ptyOpenFailed(errno: errno)
        }

        // Grant access to slave
        guard grantpt(masterFD) == 0 else {
            close(masterFD)
            masterFD = -1
            throw BridgeError.grantptFailed(errno: errno)
        }

        // Unlock slave
        guard unlockpt(masterFD) == 0 else {
            close(masterFD)
            masterFD = -1
            throw BridgeError.unlockptFailed(errno: errno)
        }

        // Get slave path
        guard let pathPtr = ptsname(masterFD) else {
            close(masterFD)
            masterFD = -1
            throw BridgeError.ptsnameFailed(errno: errno)
        }
        slavePath = String(cString: pathPtr)

        // Open slave (Ghostty will use this)
        slaveFD = open(slavePath, O_RDWR)
        guard slaveFD >= 0 else {
            close(masterFD)
            masterFD = -1
            throw BridgeError.slaveOpenFailed(errno: errno)
        }

        // Configure terminal settings
        var termios = termios()
        tcgetattr(slaveFD, &termios)

        // Raw mode - disable echo, canonical mode, etc.
        // The remote SSH server handles these
        cfmakeraw(&termios)

        tcsetattr(slaveFD, TCSANOW, &termios)

        // Start reading from PTY master
        startReadLoop()

        isRunning = true
        return slavePath
    }

    /// Stop the bridge and close PTY
    func stop() {
        isRunning = false

        readSource?.cancel()
        readSource = nil

        if slaveFD >= 0 {
            close(slaveFD)
            slaveFD = -1
        }
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
    }

    // MARK: - Data Transfer

    /// Write data to PTY master (from SSH, displayed by Ghostty)
    func writeToTerminal(_ data: Data) {
        guard masterFD >= 0 else { return }

        data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress else { return }
            let written = write(masterFD, ptr, buffer.count)
            if written < 0 {
                print("PTY write error: \(errno)")
            }
        }
    }

    /// Start reading from PTY master (terminal output → SSH)
    private func startReadLoop() {
        readQueue = DispatchQueue(label: "com.clauntty.pty.read")

        readSource = DispatchSource.makeReadSource(
            fileDescriptor: masterFD,
            queue: readQueue
        )

        readSource?.setEventHandler { [weak self] in
            self?.handleRead()
        }

        readSource?.setCancelHandler { [weak self] in
            // Cleanup if needed
            _ = self
        }

        readSource?.resume()
    }

    private func handleRead() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(masterFD, &buffer, buffer.count)

        if bytesRead > 0 {
            let data = Data(buffer[0..<bytesRead])
            DispatchQueue.main.async { [weak self] in
                self?.onDataFromTerminal?(data)
            }
        } else if bytesRead < 0 && errno != EAGAIN {
            print("PTY read error: \(errno)")
        }
    }

    // MARK: - Window Size

    /// Set terminal window size (for SSH PTY request and SIGWINCH)
    func setWindowSize(rows: UInt16, cols: UInt16) {
        guard masterFD >= 0 else { return }

        var ws = winsize()
        ws.ws_row = rows
        ws.ws_col = cols

        // Set on master
        ioctl(masterFD, TIOCSWINSZ, &ws)
    }
}

// MARK: - Errors

extension GhosttyBridge {
    enum BridgeError: Error, LocalizedError {
        case ptyOpenFailed(errno: Int32)
        case grantptFailed(errno: Int32)
        case unlockptFailed(errno: Int32)
        case ptsnameFailed(errno: Int32)
        case slaveOpenFailed(errno: Int32)

        var errorDescription: String? {
            switch self {
            case .ptyOpenFailed(let errno):
                return "Failed to open PTY: \(String(cString: strerror(errno)))"
            case .grantptFailed(let errno):
                return "Failed to grant PTY: \(String(cString: strerror(errno)))"
            case .unlockptFailed(let errno):
                return "Failed to unlock PTY: \(String(cString: strerror(errno)))"
            case .ptsnameFailed(let errno):
                return "Failed to get PTY name: \(String(cString: strerror(errno)))"
            case .slaveOpenFailed(let errno):
                return "Failed to open PTY slave: \(String(cString: strerror(errno)))"
            }
        }
    }
}
