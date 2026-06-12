import Foundation

public struct ValidationContext<Subject, Document> {
    public let document: Document
    public let subject: Subject
    public let codingPath: [CodingKey]

    public init(document: Document, subject: Subject, codingPath: [CodingKey]) {
        self.document = document
        self.subject = subject
        self.codingPath = codingPath
    }
}
