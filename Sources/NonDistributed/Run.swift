/**
 This is an example application that uses simple framework that allows the (parallel) execution
 of workers for the same type of work items.
 
 The framework is implemented in the file `Framework.swift`.
 
 The implementation of the sample use case (which uses the framwork) is in the file `DocumentProcessing`.
 */

import Foundation

@main
struct DistributedActorsTest {
    
    static func main() async throws {
        
        /// The work items.
        /// Note that they already have their unique work item IDs.
        let workitemsStack: [DocumentWorkItem] = [
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/a"), documentSize: 2, id: "4"),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/b"), documentSize: 4, id: "3"),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/c"), documentSize: 1, id: "2"),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/d"), documentSize: 3, id: "1"),
        ]
        
        let logger = PrintLogger()
        
        /// Value that is used by the following handler.
        var finished = false
        
        /// This handler will be called when all work is done.
        let allDoneHandler = { finished = true }
        
        /// Initializing the orchestration.
        let orchestration = await WorkOrchestration<DocumentWorkItem,DocumentProcessingMessage>(
            workItemsStack: workitemsStack,
            parallelWorkers: 2,
            workItemProcessorProducer: documentProcessorProducer,
            logger: logger,
            allDoneHandler: allDoneHandler
        )
        
        /// Starting the work.
        await orchestration.start()

        /// The following keeps the application alive until all work is done.
        /// The according implementation in an actual application might be smarter!
        repeat {
            
            /// Wait a bit before testing the `finished` value (again).
            try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))
            
            /// The following code might stop a worker based on some random values.
            if Int.random(in: 1...10) == 1 {
                let toStop = String(Int.random(in: 1...workitemsStack.count))
                try await orchestration.control(workerWithID: toStop, commanding: .stop)
            }
            
        } while !finished
    }
    
}
