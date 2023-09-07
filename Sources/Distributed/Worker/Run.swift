import Foundation
import ArgumentParser
import Framework

@main
struct DistributedWorker: ParsableCommand {
    
    @Argument(help: "The path to a file.")
    var path: String
    
    @Option(name: [.long], help: #"The worker ID."#)
    var workerID: String
    
    mutating func run() throws {
        sayHello(to: "DistributedWorker \(workerID) for file [\(path)]") // calling function from shared framework (in folder "DistributedFramework")
    }
    
}
