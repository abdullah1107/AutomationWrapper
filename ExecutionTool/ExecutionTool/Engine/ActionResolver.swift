//
//  ActionResolver.swift
//  Maps element type + action to a handler, and manages retries and waits.
//

import Foundation

struct ActionResolver {
    let handlers: [ElementType: StepHandler]
    /// Extra attempts after the first one fails.
    var maxRetries: Int = 2
    var retryDelay: TimeInterval = 0.5
    /// How long to wait for an element on the first attempt (a step's own "timeout" overrides it).
    var elementTimeout: TimeInterval = 10
    /// Shorter wait on retries.
    var retryTimeout: TimeInterval = 3

    /// One StandardStepHandler per XCUIElement type. Replace an entry to customise a type.
    static func standard() -> ActionResolver {
        var map: [ElementType: StepHandler] = [:]
        for type in ElementType.allCases {
            map[type] = StandardStepHandler(elementType: type)
        }
        return ActionResolver(handlers: map)
    }

    func handler(for step: AutomationStep) throws -> StepHandler {
        guard let handler = handlers[step.type] else {
            throw ExecutionError.noHandler(step.type)
        }
        guard handler.supportedActions.contains(step.resolvedAction) else {
            throw ExecutionError.unsupportedAction(step.resolvedAction, step.type)
        }
        return handler
    }

    /// Performs the step, retrying on failure. Returns the number of attempts used.
    @discardableResult
    func perform(_ step: AutomationStep, driver: UIAutomationDriver) throws -> Int {
        let handler = try handler(for: step)
        var attempt = 0
        while true {
            attempt += 1
            do {
                let timeout = attempt == 1 ? elementTimeout : retryTimeout
                try handler.execute(step, action: step.resolvedAction, driver: driver, timeout: timeout)
                return attempt
            } catch {
                if attempt > maxRetries { throw error }
                driver.wait(seconds: retryDelay)
            }
        }
    }
}
