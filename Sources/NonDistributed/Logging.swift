import Foundation

/// The protocol for a logger.
public protocol Logger {
    func log(workerID: WorkerID?, _ message: String) async
}

/// A simple logger that only prints.
actor PrintLogger: Logger {
    func log(workerID: WorkerID?, _ message: String) async {
        if let workerID {
            print("worker \(workerID): \(message)")
        } else {
            print(message)
        }
    }
}
