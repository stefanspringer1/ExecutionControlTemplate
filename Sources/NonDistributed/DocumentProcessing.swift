/**
 Here an example implementaion of a work item and an according worker is given
 to be used with the simple framework that allows the (parallel) execution
 of workers for the same type of work items.
 */

import Foundation

/// A work item that represents a document given via an URL (e.g. a file on the disk).
struct DocumentWorkItem: CustomStringConvertible, WorkItemWithID {
    let documentURL: URL
    let documentSize: Double // document size will be translated into seconds for the processing
    let _id: String
    var id: String { _id }
    
    init(documentURL: URL, documentSize: Double, id: String) {
        self.documentURL = documentURL
        self.documentSize = documentSize
        self._id = id
    }
    
    public var description: String { "work item: document \(documentURL.description)" }
}

/// The message that is communicated by the processor/worker for a document,
/// which could describe errorts that occur while processing or other information.
struct DocumentProcessingMessage: CustomStringConvertible {
    let text: String
    var description: String { text }
}

/// This is a worker for teh processing of a document.
actor DocumentProcessor: WorkItemProcessor {
    
    typealias WorkItem = DocumentWorkItem
    typealias Message = DocumentProcessingMessage
    
    let id: WorkerID
    
    enum Status {
        case initialized; case running; case paused; case stopped; case finished
    }
    
    private let workItem: WorkItem
    private let backCommunicationHandler: (WorkerID, BackCommunication<DocumentProcessingMessage>) async throws -> ()
    
    init(workerID: WorkerID, workItem: DocumentWorkItem, backCommunicationHandler: @escaping (WorkerID, BackCommunication<DocumentProcessingMessage>) async throws -> ()) {
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
                    case .paused:
                        status = .paused
                        self.desiredStatus = nil
                        try await backCommunicationHandler(id, .paused)
                        return
                    case .stopped:
                        status = .stopped
                        self.desiredStatus = nil
                        try await backCommunicationHandler(id, .stopped)
                        return
                    case .initialized, .running, .finished:
                        break
                    }
                }
                
                status = .running
                stepIndex += 1
                try await backCommunicationHandler(id, .progress(percent: 100.0 * Double(stepIndex) / Double(steps.count), description: steps[stepIndex]))
                
                // simulate step:
                let slowdown = Double.random(in: 1.0..<1.5)
                try await Task.sleep(nanoseconds: UInt64(workItem.documentSize / Double(steps.count) * slowdown * Double(NSEC_PER_SEC)))
            }
            try await backCommunicationHandler(id, .progress(percent: 100.0, description: "finished"))
            try await backCommunicationHandler(id, .finished)
            status = .finished
        }
    }
    
    func handle(control: Control) async throws {
        switch control {
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

/// This function delivers a processor/worker for a given woerk item.
let documentProcessorProducer: WorkItemProcessorProducer = { (workItem,workerID,backCommunicationHandler) in
    DocumentProcessor(workerID: workerID, workItem: workItem, backCommunicationHandler: backCommunicationHandler)
}
