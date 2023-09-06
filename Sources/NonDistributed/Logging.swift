import Foundation

/// The protocol for a logger.
public protocol Logger {
    func log(_ text: String) async
}

/// A simple logger that only prints.
actor PrintLogger: Logger {
    func log(_ text: String) async {
        print(text)
    }
}
