/**
 This is the implementation of a simple framework that allows the (parallel) execution
 of workers for the same type of work items.
 */

import Foundation

/// The worker ID is a String, it has to unique.
public typealias WorkerID = String

/// The work item type can be anything, but is has to conform to this protocol,
/// i.e. it has to provide a work item ID which will be used as worker ID.
public protocol WorkItemWithID {
    var id: WorkerID { get }
}

/// This is for the communication from the worker to the orchestration.
/// Besides communicating status (stopped etc.) or progress, a message can be passed of a choosen type.
public enum BackCommunication<Message> {
    case progress(percent: Double, description: String); case stopped; case paused; case resumed; case finished; case message(message: Message)
}

/// This is the function type for a function that handles the communication from the worker to the orchestration.
public typealias BackCommunicationHandler<Message> = (WorkerID,BackCommunication<Message>) async throws -> ()

// This is how the worker can be controled.
public enum Control {
    case start  /// Start the worker.
    case pause  /// Pause the worker.
    case resume /// Resume the worker.
    case stop   /// Stop the worker.
}

/// This is a worker (or "processor") for a work item.
/// I.e. the work for that item is done here!
public protocol WorkItemProcessor<WorkItem,Message> where WorkItem: WorkItemWithID, Message: CustomStringConvertible {
    
    associatedtype WorkItem
    associatedtype Message
    
    init(workerID: WorkerID, workItem: WorkItem, backCommunicationHandler: @escaping BackCommunicationHandler<Message>)
    func process() async throws
    
    func handle(control: Control) async throws
    
}

/// For the orchestration of the work, a function has to be provided which return a processor for a given work item.
typealias WorkItemProcessorProducer<WorkItem,Message> = (WorkItem,WorkerID,@escaping BackCommunicationHandler<Message>) async -> any WorkItemProcessor where WorkItem: WorkItemWithID, Message: CustomStringConvertible

/// This is the orchestration of the work.
///
/// An example call is the following:
///
/// ```Swift
/// let orchestration = WorkOrchestration<DocumentWorkItem,DocumentProcessingMessage>(
///     workItemsStack: workitemsStack,
///     parallelWorkers: 2,
///     workItemProcessorProducer: documentProcessorProducer,
///     logger: logger,
///     allDoneHandler: allDoneHandler
/// )
///
/// await orchestration.start()
/// ```
///
/// Note that the call of `orchestration.start()` returns immediatly after the acccording
/// amount of parallel workers have been started. After all work has been done,
/// the `allDoneHandler` given as an argument to the initializer of the `WorkOrchestration`
/// instance is being called.
///
/// If a worker has been stopped, the according work item will not hinder the orchestration
/// of asserting that all work has been done. But if a work item whose processing has been
/// pause does postpone this assertion.
public actor WorkOrchestration<WorkItem,Message> where WorkItem: WorkItemWithID, Message: CustomStringConvertible {
    
    var workitemsWaiting: [WorkItem]
    
    var workitemsFailedStarted = [WorkerID:WorkItem]()
    var workitemsStarted = [WorkerID:(workItem: WorkItem,processor: any WorkItemProcessor)]()
    var workitemsStopped = [WorkerID:(workItem: WorkItem,processor: any WorkItemProcessor)]()
    var workitemsFinsihed = [WorkerID:WorkItem]()
    
    public func control(workerWithID workerID: WorkerID, commanding control: Control) async throws {
        try await workitemsStarted[workerID]?.processor.handle(control: control)
    }
    
    let parallelWorkers: Int
    
    private let workItemProcessorProducer: WorkItemProcessorProducer<WorkItem,Message>
    private let logger: Logger
    private let allDoneHandler: () -> ()
    
    var workerCount = 0
    
    init(
        workItemsStack: [WorkItem],
        parallelWorkers: Int,
        workItemProcessorProducer: @escaping WorkItemProcessorProducer<WorkItem,Message>,
        logger: Logger,
        allDoneHandler: @escaping () -> ()
    ) async {
        await logger.log(sourceID: nil, "Initializing an orchestration for \(workItemsStack.count) work items to to processed with \(parallelWorkers) workers in parallel.")
        self.workitemsWaiting = workItemsStack
        self.parallelWorkers = parallelWorkers
        self.workItemProcessorProducer = workItemProcessorProducer
        self.logger = logger
        self.allDoneHandler = allDoneHandler
    }
    
    public func allDone() async -> Bool {
        workitemsWaiting.isEmpty && workitemsStarted.isEmpty
    }
    
    @discardableResult
    private func startNextWorker() async -> Bool {
        guard let workItem = workitemsWaiting.popLast() else {
            if await allDone() {
                await logger.log(sourceID: nil, "All done!")
                allDoneHandler()
            }
            return false
        }
        
        workerCount += 1
        let workerID = workItem.id
        let workItemProcessor = await workItemProcessorProducer(workItem, workerID, self.backCommunication)
        do {
            workitemsStarted[workerID] = (workItem,workItemProcessor)
            await logger.log(sourceID: nil, "starting #\(workerID) worker for \(workItem)")
            try await workItemProcessor.process()
        } catch {
            await logger.log(sourceID: nil, "failed starting worker for \(workItem)")
            workitemsFailedStarted[workerID] = workItem
        }
        return true
    }
    
    func start() async {
        for _ in 1...parallelWorkers {
            if await !startNextWorker() {
                break
            }
        }
    }
    
    func backCommunication(workerID: WorkerID, message: BackCommunication<Message>) async {
        switch message {
        case .progress(percent: let percent, description: let description):
            await logger.log(sourceID: workerID, "progress \(percent) %: \(description)")
        case .finished:
            await logger.log(sourceID: workerID, "finished")
            if let (workItem,_) = workitemsStarted[workerID] {
                workitemsStarted[workerID] = nil
                workitemsFinsihed[workerID] = workItem
            }
            await startNextWorker()
        case .message(message: let message):
            await logger.log(sourceID: workerID, message.description)
        case .stopped:
            if let entry = workitemsStarted[workerID] {
                workitemsStarted[workerID] = nil
                workitemsStopped[workerID] = entry
            }
            await logger.log(sourceID: workerID, "worker stopped!")
            await startNextWorker()
        case .paused:
            await logger.log(sourceID: workerID, "worker paused!")
        case .resumed:
            await logger.log(sourceID: workerID, "worker resumed...")
        }
        
    }
    
}
