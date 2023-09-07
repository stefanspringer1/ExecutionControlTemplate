import Foundation
import ArgumentParser

// The following imports are from targets in this Swift package:
import Logging
import Framework
import DocumentProcessing

@main
struct DistributedWorker: ParsableCommand {
    
    @Argument(help: "The path to a file.")
    var path: String
    
    @Option(name: [.long], help: #"The worker ID."#)
    var workerID: String
    
    mutating func run() throws {
        sayHello(to: "DistributedWorker for item \(workerID) for file \(path)") // calling function from shared framework (in folder "DistributedFramework")
    }
    
}
