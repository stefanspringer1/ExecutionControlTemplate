import Foundation

/**
 Here an example implementaion of a work item and an according worker is given
 to be used with the simple framework that allows the (parallel) execution
 of workers for the same type of work items.
 */

import Foundation

// The following imports are from targets in this Swift package:
import Framework

/// A work item that represents a document given via an URL (e.g. a file on the disk).
public struct DocumentWorkItem: CustomStringConvertible, WorkItemWithID {
    public let documentURL: URL
    private let _id: String
    public var id: String { _id }
    
    public init(documentURL: URL, id: String) {
        self.documentURL = documentURL
        self._id = id
    }
    
    public var description: String { "work item \(id): document \(documentURL.description)" }
}

/// The message that is communicated by the processor/worker for a document,
/// which could describe errorts that occur while processing or other information.
public struct DocumentProcessingMessage: CustomStringConvertible {
    public let text: String
    public var description: String { text }
}

// ... TODO ...
