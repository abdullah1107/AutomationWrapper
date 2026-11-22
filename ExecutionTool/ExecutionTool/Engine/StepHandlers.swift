//
//  StepHandlers.swift
//  Performs one action step, and evaluates verify / if conditions. Handlers only talk
//  to the UIAutomationDriver abstraction, never to XCUITest directly.
//
//  Every element type uses StandardStepHandler. To customise one type, write another
//  StepHandler and register it in ActionResolver.standard().
//

import Foundation

protocol StepHandler {
    var elementType: ElementType { get }
    var supportedActions: [ActionType] { get }
    func execute(_ step: AutomationStep, action: ActionType, driver: UIAutomationDriver, timeout: TimeInterval) throws
}

extension StepHandler {
    var supportedActions: [ActionType] { elementType.supportedActions }

    func locator(for step: AutomationStep) -> ElementLocator {
        ElementLocator(type: step.type, identifier: step.identifier)
    }

    func unsupported(_ action: ActionType) -> Error {
        ExecutionError.unsupportedAction(action, elementType)
    }
}

struct StandardStepHandler: StepHandler {
    let elementType: ElementType
    var evaluator = ConditionEvaluator()

    func execute(_ step: AutomationStep, action: ActionType, driver: UIAutomationDriver, timeout: TimeInterval) throws {
        let target = locator(for: step)
        let limit = step.timeout ?? timeout

        switch action {
        case .tap:
            try driver.perform(.tap, on: target, timeout: limit)
        case .doubleTap:
            try driver.perform(.doubleTap, on: target, timeout: limit)
        case .longPress:
            let seconds = step.value.flatMap(Double.init) ?? 1
            try driver.perform(.longPress(seconds), on: target, timeout: limit)
        case .twoFingerTap:
            try driver.perform(.twoFingerTap, on: target, timeout: limit)
        case .typeText:
            try driver.typeText(step.value ?? "", into: target, timeout: limit)
        case .clearText:
            try driver.clearText(target, timeout: limit)
        case .toggle:
            try driver.toggle(target, timeout: limit)
        case .adjustSlider:
            guard let position = step.value.flatMap(Double.init) else {
                throw DriverError.actionFailed("adjustSlider needs a value between 0 and 1.")
            }
            try driver.adjustSlider(target, to: position, timeout: limit)
        case .selectPickerValue:
            try driver.selectPickerValue(step.value ?? "", in: target, timeout: limit)
        case .swipeUp:
            try driver.perform(.swipe(.up), on: target, timeout: limit)
        case .swipeDown:
            try driver.perform(.swipe(.down), on: target, timeout: limit)
        case .swipeLeft:
            try driver.perform(.swipe(.left), on: target, timeout: limit)
        case .swipeRight:
            try driver.perform(.swipe(.right), on: target, timeout: limit)
        case .verify:
            let condition = step.resolvedCondition
            let outcome = evaluator.evaluate(condition, expected: step.value, on: target,
                                             driver: driver, timeout: limit)
            guard outcome.isTrue else {
                throw ExecutionError.verificationFailed(identifier: step.identifier,
                                                        condition: condition,
                                                        detail: outcome.detail)
            }
        }
    }
}

// MARK: - Conditions

/// Polls a condition until it is true or the timeout runs out.
/// Used by `verify` steps (false = failure) and `if` steps (false = run the else branch).
struct ConditionEvaluator {
    var pollInterval: TimeInterval = 0.25

    struct Outcome {
        let isTrue: Bool
        /// Human-readable actual state, for logs and failure messages.
        let detail: String
    }

    func evaluate(_ condition: ConditionType,
                  expected: String?,
                  on locator: ElementLocator,
                  driver: UIAutomationDriver,
                  timeout: TimeInterval) -> Outcome {
        let deadline = Date().addingTimeInterval(timeout)
        var outcome = check(condition, expected: expected, on: locator, driver: driver)
        while !outcome.isTrue && Date() < deadline {
            driver.wait(seconds: pollInterval)
            outcome = check(condition, expected: expected, on: locator, driver: driver)
        }
        return outcome
    }

    func check(_ condition: ConditionType,
               expected: String?,
               on locator: ElementLocator,
               driver: UIAutomationDriver) -> Outcome {
        // Secure fields never expose their text, so text checks fall back to existence.
        let effective: ConditionType = (locator.type == .secureTextField && condition.needsValue) ? .exists : condition
        let snapshot = driver.snapshot(locator)

        switch effective {
        case .exists:
            return Outcome(isTrue: snapshot != nil,
                           detail: snapshot != nil ? "\(locator) exists" : "\(locator) not found")
        case .notExists:
            return Outcome(isTrue: snapshot == nil,
                           detail: snapshot == nil ? "\(locator) not found" : "\(locator) still exists")
        default:
            break
        }

        guard let snapshot else {
            return Outcome(isTrue: false, detail: "\(locator) not found")
        }
        let expectedText = expected ?? ""

        switch effective {
        case .equals:
            return Outcome(isTrue: snapshot.text == expectedText,
                           detail: "expected \"\(expectedText)\", found \"\(snapshot.text)\"")
        case .contains:
            return Outcome(isTrue: snapshot.text.contains(expectedText),
                           detail: "expected text containing \"\(expectedText)\", found \"\(snapshot.text)\"")
        case .enabled:
            return Outcome(isTrue: snapshot.isEnabled, detail: "isEnabled = \(snapshot.isEnabled)")
        case .disabled:
            return Outcome(isTrue: !snapshot.isEnabled, detail: "isEnabled = \(snapshot.isEnabled)")
        case .selected:
            return Outcome(isTrue: snapshot.isSelected, detail: "isSelected = \(snapshot.isSelected)")
        case .notSelected:
            return Outcome(isTrue: !snapshot.isSelected, detail: "isSelected = \(snapshot.isSelected)")
        case .hittable:
            return Outcome(isTrue: snapshot.isHittable, detail: "isHittable = \(snapshot.isHittable)")
        case .exists, .notExists:
            return Outcome(isTrue: true, detail: "")   // handled above
        }
    }
}
