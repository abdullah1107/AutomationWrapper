//
//  WorkflowLoader.swift
//  JSON Decoder: finds the workflow file, reads it, parses it and validates
//  the schema / version (validation lives in the shared WorkflowCodec).
//  Also decides which app to drive.
//

import Foundation

enum WorkflowLoaderError: LocalizedError {
    case fileNotFound(String)
    case missingBundleIdentifier

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            return "Workflow file not found: \(path)"
        case .missingBundleIdentifier:
            return "No target app. Add \"bundleIdentifier\" to the workflow JSON " +
                "or pass TARGET_BUNDLE_ID (run_workflow.sh --bundle-id …)."
        }
    }
}

enum WorkflowSource {
    /// Absolute path of a workflow.json on the Mac. Set by run_workflow.sh
    /// (TEST_RUNNER_WORKFLOW_PATH) or in the scheme's Test environment.
    static let workflowPathKey = "WORKFLOW_PATH"
    /// Optional override of the workflow's bundleIdentifier.
    static let bundleIDKey = "TARGET_BUNDLE_ID"
    /// Fallback file bundled with the runner.
    static let bundledName = "login_workflow"

    static func resolveURL(in bundle: Bundle,
                           environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        if let path = environment[workflowPathKey], !path.isEmpty {
            guard FileManager.default.fileExists(atPath: path) else {
                throw WorkflowLoaderError.fileNotFound(path)
            }
            return URL(fileURLWithPath: path)
        }
        guard let url = bundle.url(forResource: bundledName, withExtension: "json") else {
            throw WorkflowLoaderError.fileNotFound("\(bundledName).json in the runner bundle")
        }
        return url
    }

    /// Environment override first, then the workflow's own bundleIdentifier.
    static func targetBundleIdentifier(for workflow: Workflow,
                                       environment: [String: String] = ProcessInfo.processInfo.environment) throws -> String {
        if let override = environment[bundleIDKey], !override.isEmpty {
            return override
        }
        if let fromJSON = workflow.bundleIdentifier, !fromJSON.isEmpty {
            return fromJSON
        }
        throw WorkflowLoaderError.missingBundleIdentifier
    }
}

struct WorkflowLoader {
    func load(from url: URL) throws -> Workflow {
        let data = try Data(contentsOf: url)
        return try WorkflowCodec.decode(data)
    }
}
