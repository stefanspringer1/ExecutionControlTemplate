import Foundation
import ArgumentParser
import Utilities
import Framework

@main
struct DistributedMaster: ParsableCommand {
    
    @Argument(help: "The path, denoting either a directory or a file.")
    var path: String
    
    @Option(name: [.long], help: #"The pattern for file names to search for."#)
    var filePattern: String = #"[def][0-9abcdef]{7}\.xml"#
    
    mutating func run() throws {
        
        sayHello(to: "DistributedMaster") // calling function from shared framework (in folder "DistributedFramework")
        
        let url = URL(fileURLWithPath: path)
        let workerProgram =  URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appending(component: "DistributedWorker")
        
        let files = try url.files(withPattern: filePattern, findRecursively: true)
        
        var workerCount = 0
        for file in files {
            workerCount += 1
            runProgram(
                executableURL: workerProgram,
                environment: nil,
                arguments: [
                    file.osPath,
                    "--worker-id",
                    String(workerCount),
                ],
                currentDirectoryURL: workerProgram.deletingLastPathComponent(), // to be changed
                qualityOfService: .default,
                standardOutHandler: { print($0) }, // TODO: use logger
                errorOutHandler: { print(($0), to: &StandardError.instance) }, // TODO: use logger
                commandLineDebugHandler: { _ in } // TODO: use logger
            )
        }
    }
    
}
