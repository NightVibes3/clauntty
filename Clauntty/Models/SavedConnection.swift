import Foundation

/// Represents a saved SSH connection configuration
struct SavedConnection: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var lastConnected: Date?

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.lastConnected = lastConnected
    }

    /// Display name - uses custom name or falls back to user@host
    var displayName: String {
        name.isEmpty ? "\(username)@\(host)" : name
    }
}

/// Authentication method for SSH connections
enum AuthMethod: Codable, Hashable {
    case password
    case sshKey(keyId: String)

    var displayName: String {
        switch self {
        case .password:
            return "Password"
        case .sshKey:
            return "SSH Key"
        }
    }
}
