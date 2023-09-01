import Foundation
import Distributed

// ------- general formulation:

protocol WorkItemProcessor {
    
    associatedtype WorkItem
    associatedtype BackCommunication
    associatedtype ForwardCommunication
    
    init(workItem: WorkItem, backCommunicationHandler: @escaping (BackCommunication)  -> ())
    
    func handle(forwardCommunication: ForwardCommunication) async throws
    
}

// ------- implementation of processor:

struct DocumentWorkItem {
    let documentURL: URL
}

enum StatusMessage {
    case Progress(percent: Double, description: String); case Finsihed; case logItem(text: String)
}

enum Steering {
    case start; case pause; case resume; case stop
}

actor DocumentProcessor: WorkItemProcessor {

    enum Status {
        case initialized; case running; case paused; case stopped; case finished
    }
    
    typealias WorkItem = DocumentWorkItem
    typealias BackCommunication = StatusMessage
    typealias ForwardCommunication = Steering
    
    private let workItem: WorkItem
    private let backCommunicationHandler: (StatusMessage) async throws -> ()
    
    init(workItem: DocumentWorkItem, backCommunicationHandler: @escaping (StatusMessage) -> ()) {
        self.workItem = workItem
        self.backCommunicationHandler = backCommunicationHandler
    }
    
    private let steps = ["step1", "step2", "step3", "step4"]
    private var stepIndex = -1
    private var status: Status = .initialized
    private var desiredStatus: Status? = nil
    
    private func process() async throws {
        guard status != .stopped && status != .finished else { return }
        
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
            try await backCommunicationHandler(.Progress(percent: 100.0 * Double(stepIndex + 1) / Double(steps.count), description: steps[stepIndex]))
            
            // simulate step:
            let seconds: Double = 3
            try await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
        }
        status = .finished
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

// ------- using:

// ... TODO ...
