import Foundation
import Distributed

// ------- Logger:

public protocol Logger {
    func log(_ text: String) async
}

actor PrintLogger: Logger {
    func log(_ text: String) async {
        print(text)
    }
}

// ------- general formulation:

public typealias WorkerID = Int

public protocol WorkItemProcessor {
    
    associatedtype WorkItem
    associatedtype BackCommunication
    associatedtype ForwardCommunication
    
    init(workerID: WorkerID, workItem: WorkItem, backCommunicationHandler: @escaping (WorkerID,BackCommunication) async -> ())
    func process() async throws
    
    func handle(forwardCommunication: ForwardCommunication) async throws
    
}

// ------- implementation of processor:

struct DocumentWorkItem: CustomStringConvertible {
    let documentURL: URL
    let documentSize: Double
    public var description: String { "work item: document \(documentURL.description)" }
}

enum StatusMessage {
    case progress(percent: Double, description: String); case finished; case logItem(text: String)
}

enum Steering {
    case start; case pause; case resume; case stop
}

actor DocumentProcessor: WorkItemProcessor {
    
    let id: Int
    
    enum Status {
        case initialized; case running; case paused; case stopped; case finished
    }
    
    typealias WorkItem = DocumentWorkItem
    typealias BackCommunication = StatusMessage
    typealias ForwardCommunication = Steering
    
    private let workItem: WorkItem
    private let backCommunicationHandler: (WorkerID,StatusMessage) async throws -> ()
    
    init(workerID: WorkerID, workItem: DocumentWorkItem, backCommunicationHandler: @escaping (WorkerID,StatusMessage) async -> ()) {
        self.id = workerID
        self.workItem = workItem
        self.backCommunicationHandler = backCommunicationHandler
    }
    
    private let steps = ["step1", "step2", "step3", "step4"]
    private var stepIndex = -1
    private var status: Status = .initialized
    private var desiredStatus: Status? = nil
    
    public func process() async throws {
        guard status != .stopped && status != .finished else { return }
        
        Task {
            while stepIndex + 1 < steps.count {
                
                if let desiredStatus = self.desiredStatus {
                    switch desiredStatus {
                    case .paused, .stopped:
                        status = desiredStatus
                        self.desiredStatus = nil
                        return
                    case .initialized, .running, .finished:
                        break
                    }
                }
                
                status = .running
                stepIndex += 1
                try await backCommunicationHandler(id, .progress(percent: 100.0 * Double(stepIndex) / Double(steps.count), description: steps[stepIndex]))
                
                // simulate step:
                try await Task.sleep(nanoseconds: UInt64(workItem.documentSize * Double.random(in: 1..<1.5) * Double(NSEC_PER_SEC)))
            }
            try await backCommunicationHandler(id, .progress(percent: 100.0, description: "finished"))
            try await backCommunicationHandler(id, .finished)
            status = .finished
        }
    }
    
    func handle(forwardCommunication: Steering) async throws {
        switch forwardCommunication {
        case .start:
            try await process()
        case .pause:
            desiredStatus = .paused
        case .resume:
            try await process()
        case .stop:
            desiredStatus = .stopped
        }
    }
    
}

actor WorkOrchestration {
    
    var workitemsWaiting: [DocumentWorkItem]
    
    var workitemsFailedStarted = [WorkerID:DocumentWorkItem]()
    var workitemsStarted = [WorkerID:(DocumentWorkItem,DocumentProcessor)]()
    var workitemsFinsihed = [WorkerID:DocumentWorkItem]()
    
    let parallelWorkers: Int
    
    private let logger: Logger
    
    var workerCount = 0
    
    init(workitems: [DocumentWorkItem], parallelWorkers: Int, logger: Logger) {
        self.workitemsWaiting = workitems
        self.parallelWorkers = parallelWorkers
        self.logger = logger
    }
    
    @discardableResult
    private func startNextWorker() async -> Bool {
        guard let workItem = workitemsWaiting.popLast() else {
            if workitemsStarted.isEmpty {
                await logger.log("All done!")
            }
            return false
        }
        
        workerCount += 1; let workerID = workerCount
        let workItemProcessor = DocumentProcessor(workerID: workerCount,workItem: workItem, backCommunicationHandler: self.backCommunication)
        do {
            workitemsStarted[workerID] = (workItem,workItemProcessor)
            await logger.log("starting #\(workerID) worker for \(workItem)")
            try await workItemProcessor.process()
        } catch {
            await logger.log("failed starting worker for \(workItem)")
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
    
    func backCommunication(workerID: WorkerID, message: StatusMessage) async {
        switch message {
        case .progress(percent: let percent, description: let description):
            await logger.log("worker \(workerID): progress \(percent) %: \(description)")
        case .finished:
            await logger.log("worker \(workerID): finished")
            if let (workItem,_) = workitemsStarted[workerID] {
                workitemsStarted[workerID] = nil
                workitemsFinsihed[workerID] = workItem
            }
            await startNextWorker()
        case .logItem(text: let text):
            await logger.log("worker \(workerID): info: \(text)")
        }
         
    }
    
}

// ------- using:

@main
struct DistributedActorsTest {
    
    static func main() async throws {
        
        let workitems: [DocumentWorkItem] = [
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/a"), documentSize: 2),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/b"), documentSize: 4),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/c"), documentSize: 1),
            DocumentWorkItem(documentURL: URL(fileURLWithPath: "/d"), documentSize: 3),
        ]
        
        let logger = PrintLogger()
        
        let orchestration = WorkOrchestration(workitems: workitems, parallelWorkers: 2, logger: logger)
        
        await orchestration.start()
        
        _ = readLine()
    }
    
}
