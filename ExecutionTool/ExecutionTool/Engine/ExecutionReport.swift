//
//  ExecutionReport.swift
//  Result of running a workflow, step by step.
//

import Foundation

enum StepStatus: String {
    case passed = "PASS"
    case failed = "FAIL"
    case skipped = "SKIP"
}

struct StepResult {
    let step: AutomationStep
    let status: StepStatus
    let duration: TimeInterval
    let attempts: Int
    let message: String?

    var line: String {
        let what: String
        if step.isLoop {
            what = "loop ×\(step.resolvedRepeatCount)"
        } else if step.isIf {
            what = "if \(step.type.rawValue) '\(step.identifier)' \(step.resolvedCondition.rawValue)"
        } else {
            what = "\(step.resolvedAction.rawValue) \(step.type.rawValue) '\(step.identifier)'"
        }
        let base = "[\(status.rawValue)] step \(step.id): \(what)"
        let timing = String(format: " (%.2fs, attempts: %d)", duration, attempts)
        return base + timing + (message.map { " – \($0)" } ?? "")
    }
}

struct ExecutionReport {
    let workflowName: String
    var results: [StepResult] = []

    var passed: Bool { !results.contains { $0.status == .failed } }

    var summary: String {
        let passedCount = results.filter { $0.status == .passed }.count
        let failedCount = results.filter { $0.status == .failed }.count
        let skippedCount = results.filter { $0.status == .skipped }.count
        let header = "Workflow '\(workflowName)': \(passed ? "PASSED" : "FAILED") " +
            "(\(passedCount) passed, \(failedCount) failed, \(skippedCount) skipped)"
        return ([header] + results.map(\.line)).joined(separator: "\n")
    }
}

enum ExecutionError: LocalizedError {
    case noHandler(ElementType)
    case unsupportedAction(ActionType, ElementType)
    case verificationFailed(identifier: String, condition: ConditionType, detail: String)

    var errorDescription: String? {
        switch self {
        case let .noHandler(type):
            return "No handler registered for element type '\(type.rawValue)'."
        case let .unsupportedAction(action, type):
            return "Action '\(action.rawValue)' is not supported for '\(type.rawValue)'."
        case let .verificationFailed(identifier, condition, detail):
            return "Verify '\(identifier)' \(condition.rawValue) failed: \(detail)."
        }
    }
}
