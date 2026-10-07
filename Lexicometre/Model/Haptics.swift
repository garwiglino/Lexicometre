#if canImport(UIKit)
import UIKit
#endif

/// Tactile feedback, silent when disabled in the settings.
@MainActor
enum Haptics {
    static var enabled = true

    static func success() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if canImport(UIKit)
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    static func soft() {
        #if canImport(UIKit)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    static func tap() {
        #if canImport(UIKit)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func celebrate() {
        #if canImport(UIKit)
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
}
