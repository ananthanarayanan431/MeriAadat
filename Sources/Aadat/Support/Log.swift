import Foundation
import os

/// Unified logging categories. Visible in Console.app.
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "io.github.ananthanarayanan431.aadat"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let storage = Logger(subsystem: subsystem, category: "storage")
}
