import Foundation
import ArgumentParser
import Utilities

// The following imports are from targets in this Swift package:
import Logging
import Framework
import DocumentProcessing

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
        
        var workitemsStack: [DocumentWorkItem]
        do {
            var count = 0
            workitemsStack = files.map{ file in
                count += 1
                return DocumentWorkItem(documentURL: file, id: String(count))
            }
        }
        
        while let workItem = workitemsStack.popLast() {

            runProgram(
                executableURL: workerProgram,
                environment: nil,
                arguments: [
                    workItem.documentURL.osPath,
                    "--worker-id",
                    workItem.id,
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
