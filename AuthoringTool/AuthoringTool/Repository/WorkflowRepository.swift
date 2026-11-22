//
//  WorkflowRepository.swift
//  JSON Encoder / Repository: converts the model to JSON and saves / loads files.
//

import Foundation

struct WorkflowRepository {
    /// Validates, encodes and atomically writes the workflow.
    func save(_ workflow: Workflow, to url: URL) throws {
        try WorkflowCodec.validate(workflow)
        let data = try WorkflowCodec.encode(workflow)
        try data.write(to: url, options: .atomic)
    }

    /// Reads, decodes and validates (including version check) a workflow file.
    func load(from url: URL) throws -> Workflow {
        let data = try Data(contentsOf: url)
        return try WorkflowCodec.decode(data)
    }

    func jsonString(for workflow: Workflow) throws -> String {
        let data = try WorkflowCodec.encode(workflow)
        return String(decoding: data, as: UTF8.self)
    }
}
