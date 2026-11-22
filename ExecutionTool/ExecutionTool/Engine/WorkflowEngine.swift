//
//  WorkflowEngine.swift
//  Executes steps in order, handles wait times, if / else branches, loops, error handling & reporting.
//  Prints the execution sequence live, one line per step (nested steps are indented).
//

import Foundation

final class WorkflowEngine {
    let driver: UIAutomationDriver
    let resolver: ActionResolver
    let evaluator: ConditionEvaluator
    /// Stop at the first failing step (remaining steps are reported as skipped).
    var stopOnFailure: Bool
    /// How long an `if` step waits for its condition to become true when it has no own "timeout".
    var conditionTimeout: TimeInterval = 3

    /// Where the live sequence log goes (stdout by default, visible in xcodebuild output).
    var log: (String) -> Void = { print("[WORKFLOW] \($0)") }
    /// Lets the caller wrap each step, e.g. in an XCTContext activity for the test report.
    var stepWrapper: (String, () -> Void) -> Void = { _, body in body() }
    /// Called when a step fails (e.g. to attach a screenshot).
    var onStepFailure: ((AutomationStep, Error) -> Void)?

    private var report = ExecutionReport(workflowName: "")
    private var halted = false

    init(driver: UIAutomationDriver,
         resolver: ActionResolver = .standard(),
         evaluator: ConditionEvaluator = ConditionEvaluator(),
         stopOnFailure: Bool = true) {
        self.driver = driver
        self.resolver = resolver
        self.evaluator = evaluator
        self.stopOnFailure = stopOnFailure
    }

    func run(_ workflow: Workflow) -> ExecutionReport {
        report = ExecutionReport(workflowName: workflow.name)
        halted = false
        let nested = workflow.totalStepCount - workflow.steps.count
        log("Executing '\(workflow.name)' – \(workflow.steps.count) steps" +
            (nested > 0 ? " (+\(nested) inside if/else/loop blocks)" : ""))

        run(workflow.steps, depth: 0)

        log(report.passed ? "RESULT: PASSED" : "RESULT: FAILED")
        return report
    }

    // MARK: - Steps

    private func run(_ steps: [AutomationStep], depth: Int) {
        for step in steps {
            if halted || !step.isEnabled {
                skip(step, reason: halted ? "skipped after earlier failure" : "disabled", depth: depth)
                continue
            }
            switch step.resolvedKind {
            case .action: runAction(step, depth: depth)
            case .ifElse: runIf(step, depth: depth)
            case .loop:   runLoop(step, depth: depth)
            }
        }
    }

    private func runAction(_ step: AutomationStep, depth: Int) {
        let tag = Self.tag(step, depth: depth)
        let description = Self.describe(step)
        log("\(tag) RUN   \(description)")

        stepWrapper("Step \(step.id): \(description)") {
            let start = Date()
            do {
                let attempts = try self.resolver.perform(step, driver: self.driver)
                if let wait = step.waitTime, wait > 0 {
                    self.driver.wait(seconds: wait)
                }
                let duration = Date().timeIntervalSince(start)
                self.log("\(tag) PASS  \(description)" + String(format: " (%.1fs)", duration))
                self.report.results.append(StepResult(step: step, status: .passed, duration: duration,
                                                      attempts: attempts, message: nil))
            } catch {
                let duration = Date().timeIntervalSince(start)
                self.log("\(tag) FAIL  \(description) – \(error.localizedDescription)")
                self.report.results.append(StepResult(step: step, status: .failed, duration: duration,
                                                      attempts: self.resolver.maxRetries + 1,
                                                      message: error.localizedDescription))
                self.onStepFailure?(step, error)
                if self.stopOnFailure { self.halted = true }
            }
        }
    }

    private func runIf(_ step: AutomationStep, depth: Int) {
        let tag = Self.tag(step, depth: depth)
        let description = Self.describe(step)
        log("\(tag) IF    \(description)")

        stepWrapper("Step \(step.id): IF \(description)") {
            let start = Date()
            let locator = ElementLocator(type: step.type, identifier: step.identifier)
            let outcome = self.evaluator.evaluate(step.resolvedCondition,
                                                  expected: step.value,
                                                  on: locator,
                                                  driver: self.driver,
                                                  timeout: step.timeout ?? self.conditionTimeout)
            let branch = (outcome.isTrue ? step.thenSteps : step.elseSteps) ?? []
            let branchName = outcome.isTrue ? "THEN" : "ELSE"
            let duration = Date().timeIntervalSince(start)

            self.log("\(tag) \(outcome.isTrue ? "TRUE " : "FALSE") \(outcome.detail) → \(branchName)" +
                     " (\(branch.count) step\(branch.count == 1 ? "" : "s"))")
            self.report.results.append(StepResult(step: step, status: .passed, duration: duration, attempts: 1,
                                                  message: "condition \(outcome.isTrue) → \(branchName.lowercased())"))

            if let wait = step.waitTime, wait > 0 {
                self.driver.wait(seconds: wait)
            }
            self.run(branch, depth: depth + 1)
        }
        log("\(tag) END IF")
    }

    private func runLoop(_ step: AutomationStep, depth: Int) {
        let tag = Self.tag(step, depth: depth)
        let count = step.resolvedRepeatCount
        let body = step.loopSteps ?? []
        log("\(tag) LOOP  \(Self.describe(step))")

        stepWrapper("Step \(step.id): \(Self.describe(step))") {
            let start = Date()
            var completed = 0
            for iteration in 1...count {
                if self.halted { break }
                self.log("\(tag) ITER  \(iteration)/\(count)")
                self.stepWrapper("Iteration \(iteration)/\(count)") {
                    self.run(body, depth: depth + 1)
                }
                if !self.halted { completed += 1 }
            }
            let duration = Date().timeIntervalSince(start)
            self.report.results.append(StepResult(step: step, status: self.halted ? .failed : .passed,
                                                  duration: duration, attempts: completed,
                                                  message: "\(completed)/\(count) iterations completed"))
            if !self.halted, let wait = step.waitTime, wait > 0 {
                self.driver.wait(seconds: wait)
            }
        }
        log("\(tag) END LOOP")
    }

    /// Reports a step (and, for an if block, everything inside it) as skipped.
    private func skip(_ step: AutomationStep, reason: String, depth: Int) {
        log("\(Self.tag(step, depth: depth)) SKIP  \(Self.describe(step)) – \(reason)")
        report.results.append(StepResult(step: step, status: .skipped, duration: 0, attempts: 0, message: reason))
        for child in step.children {
            skip(child, reason: reason, depth: depth + 1)
        }
    }

    // MARK: - Formatting

    private static func tag(_ step: AutomationStep, depth: Int) -> String {
        String(repeating: "  ", count: depth) + "[\(step.id)]"
    }

    static func describe(_ step: AutomationStep) -> String {
        if step.isLoop {
            let name = step.label.map { " '\($0)'" } ?? ""
            return "repeat\(name) \(step.resolvedRepeatCount)×, \((step.loopSteps ?? []).count) step(s)"
        }
        let element = "\(step.type.rawValue) '\(step.identifier)'"
        let shownValue: String? = step.value.map { value in
            step.type == .secureTextField ? String(repeating: "•", count: value.count) : value
        }

        if step.isIf || step.resolvedAction == .verify {
            let condition = step.resolvedCondition
            var text = step.isIf ? "\(element) \(condition.rawValue)" : "verify \(element) \(condition.rawValue)"
            if condition.needsValue, let shownValue { text += " \"\(shownValue)\"" }
            return text
        }

        var text = "\(step.resolvedAction.rawValue) \(element)"
        if let shownValue, !shownValue.isEmpty { text += " = \"\(shownValue)\"" }
        return text
    }
}
