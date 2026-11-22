//
//  UIAutomationDriver.swift
//  Generic interface for UI operations. XCUITestDriver is one implementation;
//  another (e.g. Appium, a mock for unit tests) can be swapped in.
//

import Foundation

struct ElementLocator: CustomStringConvertible {
    let type: ElementType
    let identifier: String

    var description: String { "\(type.rawValue) '\(identifier)'" }
}

enum SwipeDirection: String {
    case up, down, left, right
}

enum Gesture {
    case tap
    case doubleTap
    case longPress(TimeInterval)
    case twoFingerTap
    case swipe(SwipeDirection)
}

/// State of an element at one moment, used to evaluate verify / if conditions.
struct ElementSnapshot {
    let isEnabled: Bool
    /// `isSelected`, or "on" for switches / check boxes.
    let isSelected: Bool
    let isHittable: Bool
    /// Value for value-bearing elements (fields, switches, sliders…), label otherwise.
    let text: String
}

enum DriverError: LocalizedError {
    case elementNotFound(ElementLocator, timeout: TimeInterval)
    case notHittable(ElementLocator)
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .elementNotFound(locator, timeout):
            return "\(locator) not found within \(Int(timeout))s."
        case let .notHittable(locator):
            return "\(locator) exists but is not hittable."
        case let .actionFailed(message):
            return message
        }
    }
}

protocol UIAutomationDriver: AnyObject {
    /// Current state of the element, or nil if it does not exist right now (never waits).
    func snapshot(_ locator: ElementLocator) -> ElementSnapshot?
    func exists(_ locator: ElementLocator, timeout: TimeInterval) -> Bool
    func perform(_ gesture: Gesture, on locator: ElementLocator, timeout: TimeInterval) throws
    func typeText(_ text: String, into locator: ElementLocator, timeout: TimeInterval) throws
    func clearText(_ locator: ElementLocator, timeout: TimeInterval) throws
    func toggle(_ locator: ElementLocator, timeout: TimeInterval) throws
    func adjustSlider(_ locator: ElementLocator, to position: Double, timeout: TimeInterval) throws
    func selectPickerValue(_ value: String, in locator: ElementLocator, timeout: TimeInterval) throws
    func getText(_ locator: ElementLocator, timeout: TimeInterval) throws -> String
    func wait(seconds: TimeInterval)
}
