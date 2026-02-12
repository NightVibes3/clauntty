import UIKit

/// Utility to safely create UIGlassEffect using reflection.
/// This avoids "cannot find in scope" compiler errors when using SDKs that don't yet define it,
/// while still allowing it to work on firmwares (like iOS 26.1-26.3) that support it.
enum SafeGlassEffect {
    /// Attempt to create a UIVisualEffect that is a UIGlassEffect if supported by the OS.
    /// - Parameter interactive: Whether the glass effect should be interactive.
    /// - Returns: A UIVisualEffect (UIGlassEffect if possible, otherwise UIBlurEffect or nil).
    static func create(interactive: Bool = true) -> UIVisualEffect {
        // First try to get the class via reflection
        if let GlassClass = NSClassFromString("UIGlassEffect") as? NSObject.Type {
            let effect = (GlassClass.init() as? UIVisualEffect)
            
            // Set interactivity if supported (UIGlassEffect has an isInteractive property)
            // We use KVC here to avoid compiler issues with unknown property.
            if let glass = effect {
                glass.setValue(interactive, forKey: "isInteractive")
                return glass
            }
        }
        
        // Fallback to a standard blur effect if UIGlassEffect is unavailable
        return UIBlurEffect(style: .systemMaterial)
    }
}
