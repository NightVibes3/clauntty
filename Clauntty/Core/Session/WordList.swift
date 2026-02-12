import Foundation

/// Generates random session names in "adjective-noun" format
enum SessionNameGenerator {

    private static let adjectives = [
        "swift", "quiet", "bold", "calm", "bright", "dark", "fast", "slow",
        "warm", "cool", "wild", "tame", "soft", "deep", "high", "low",
        "long", "short", "wide", "thin", "young", "fresh", "dry", "wet",
        "hot", "cold", "sweet", "rich", "full", "open", "near", "far",
        "early", "late", "easy", "rough", "smooth", "sharp", "loud", "clear",
        "fuzzy", "brave", "shy", "proud", "humble", "eager", "lazy", "keen",
        "vivid", "pale", "stark", "mild", "fierce", "gentle", "sturdy", "sleek",
        "rustic", "cosmic", "lunar", "solar", "stellar", "arctic", "tropic", "misty",
        "dusty", "glossy", "matte", "silent", "noisy", "rapid", "steady", "agile",
        "nimble", "clever", "wise", "ancient", "modern", "primal", "golden", "silver",
        "iron", "copper", "jade", "amber", "coral", "ivory", "onyx", "ruby",
        "azure", "scarlet", "violet", "cobalt", "crimson", "emerald", "marble", "granite"
    ]

    private static let nouns = [
        "falcon", "river", "tiger", "mountain", "ocean", "forest", "desert", "island",
        "valley", "canyon", "meadow", "glacier", "volcano", "comet", "meteor", "planet",
        "nebula", "photon", "crystal", "prism", "cipher", "token", "buffer", "cache",
        "thread", "socket", "kernel", "daemon", "vector", "matrix", "tensor", "qubit",
        "spark", "flame", "ember", "frost", "storm", "thunder", "lightning", "breeze",
        "wave", "tide", "reef", "delta", "gorge", "ridge", "summit", "basin",
        "grove", "thicket", "marsh", "lagoon", "cavern", "crater", "dune", "cliff",
        "falcon", "hawk", "eagle", "raven", "owl", "crane", "heron", "swan",
        "wolf", "fox", "bear", "deer", "elk", "lynx", "otter", "badger",
        "salmon", "trout", "bass", "pike", "carp", "perch", "sturgeon", "marlin",
        "oak", "pine", "cedar", "maple", "birch", "willow", "aspen", "spruce",
        "quartz", "topaz", "opal", "pearl", "jasper", "agate", "garnet", "zircon"
    ]

    /// Generate a random session name like "swift-falcon"
    static func generate() -> String {
        let adjective = adjectives.randomElement() ?? "new"
        let noun = nouns.randomElement() ?? "session"
        return "\(adjective)-\(noun)"
    }

    /// Validate a session name (a-zA-Z0-9- only)
    static func isValid(_ name: String) -> Bool {
        let pattern = "^[a-zA-Z0-9-]+$"
        return name.range(of: pattern, options: .regularExpression) != nil && !name.isEmpty
    }
}
