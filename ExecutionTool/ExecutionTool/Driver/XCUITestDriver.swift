//
//  XCUITestDriver.swift
//  UIAutomationDriver implemented with XCUIApplication – performs the actual UI actions.
//

import XCTest

final class XCUITestDriver: UIAutomationDriver {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Element lookup

    private func query(for type: ElementType) -> XCUIElementQuery {
        app.descendants(matching: type.xcuiType)
    }

    func element(for locator: ElementLocator, timeout: TimeInterval) throws -> XCUIElement {
        let primary = query(for: locator.type).matching(identifier: locator.identifier).firstMatch
        if primary.waitForExistence(timeout: timeout) {
            return primary
        }
        // Fallback: the element may be exposed with a different type than authored.
        let fallback = anyMatch(locator)
        if fallback.exists {
            return fallback
        }
        throw DriverError.elementNotFound(locator, timeout: timeout)
    }

    /// Lookup without waiting (used for polling conditions).
    private func immediateElement(_ locator: ElementLocator) -> XCUIElement? {
        let primary = query(for: locator.type).matching(identifier: locator.identifier).firstMatch
        if primary.exists { return primary }
        let fallback = anyMatch(locator)
        return fallback.exists ? fallback : nil
    }

    private func anyMatch(_ locator: ElementLocator) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: locator.identifier).firstMatch
    }

    private func hittableElement(_ locator: ElementLocator, timeout: TimeInterval) throws -> XCUIElement {
        let element = try element(for: locator, timeout: timeout)
        guard waitUntil(element, matches: "isHittable == true", timeout: 3) else {
            throw DriverError.notHittable(locator)
        }
        return element
    }

    // MARK: - UIAutomationDriver

    func snapshot(_ locator: ElementLocator) -> ElementSnapshot? {
        guard let element = immediateElement(locator) else { return nil }
        let value = stringValue(of: element)
        let isOn = locator.type.isToggleable && value == "1"
        return ElementSnapshot(isEnabled: element.isEnabled,
                               isSelected: element.isSelected || isOn,
                               isHittable: element.isHittable,
                               text: text(of: element, type: locator.type))
    }

    func exists(_ locator: ElementLocator, timeout: TimeInterval) -> Bool {
        (try? element(for: locator, timeout: timeout)) != nil
    }

    func perform(_ gesture: Gesture, on locator: ElementLocator, timeout: TimeInterval) throws {
        switch gesture {
        case .tap:
            try hittableElement(locator, timeout: timeout).tap()
        case .doubleTap:
            try hittableElement(locator, timeout: timeout).doubleTap()
        case let .longPress(duration):
            try hittableElement(locator, timeout: timeout).press(forDuration: duration)
        case .twoFingerTap:
            try hittableElement(locator, timeout: timeout).twoFingerTap()
        case let .swipe(direction):
            // Containers (scroll views, tables, maps) are not always reported hittable, so only require existence.
            let element = try element(for: locator, timeout: timeout)
            switch direction {
            case .up:    element.swipeUp()
            case .down:  element.swipeDown()
            case .left:  element.swipeLeft()
            case .right: element.swipeRight()
            }
        }
    }

    func typeText(_ text: String, into locator: ElementLocator, timeout: TimeInterval) throws {
        let element = try hittableElement(locator, timeout: timeout)
        element.tap()
        clearContents(of: element)
        element.typeText(text)
    }

    func clearText(_ locator: ElementLocator, timeout: TimeInterval) throws {
        let element = try hittableElement(locator, timeout: timeout)
        element.tap()
        clearContents(of: element)
    }

    func toggle(_ locator: ElementLocator, timeout: TimeInterval) throws {
        let element = try element(for: locator, timeout: timeout)
        let before = stringValue(of: element)

        // SwiftUI Toggles expose an inner switch; tapping it (or the knob area) is reliable,
        // whereas tapping the centre of the row can hit only the label.
        let inner = element.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else if locator.type == .toggleSwitch {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        } else {
            element.tap()   // check boxes, radio buttons, disclosure triangles
        }

        guard let before else { return }
        if !waitUntil(element, matches: "value != %@", argument: before, timeout: 2) {
            // One more attempt on the knob area before giving up.
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            guard waitUntil(element, matches: "value != %@", argument: before, timeout: 2) else {
                throw DriverError.actionFailed("'\(locator.identifier)' did not change state (still \(before)).")
            }
        }
    }

    func adjustSlider(_ locator: ElementLocator, to position: Double, timeout: TimeInterval) throws {
        let element = try element(for: locator, timeout: timeout)
        let slider = element.elementType == .slider ? element : element.sliders.firstMatch
        guard slider.exists else {
            throw DriverError.actionFailed("\(locator) does not contain a slider.")
        }
        slider.adjust(toNormalizedSliderPosition: CGFloat(position))
    }

    func selectPickerValue(_ value: String, in locator: ElementLocator, timeout: TimeInterval) throws {
        let element = try element(for: locator, timeout: timeout)
        let wheel = element.elementType == .pickerWheel ? element : element.pickerWheels.firstMatch
        guard wheel.exists else {
            throw DriverError.actionFailed("\(locator) does not contain a picker wheel.")
        }
        wheel.adjust(toPickerWheelValue: value)
    }

    func getText(_ locator: ElementLocator, timeout: TimeInterval) throws -> String {
        text(of: try element(for: locator, timeout: timeout), type: locator.type)
    }

    func wait(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: - Helpers

    private func stringValue(of element: XCUIElement) -> String? {
        switch element.value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

    private func text(of element: XCUIElement, type: ElementType) -> String {
        let value = stringValue(of: element) ?? ""
        if type.readsValue {
            return value.isEmpty ? element.label : value
        }
        return element.label.isEmpty ? value : element.label
    }

    /// Clears existing text (placeholder text is not real content).
    private func clearContents(of element: XCUIElement) {
        if let current = element.value as? String,
           !current.isEmpty,
           current != element.placeholderValue {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
    }

    private func waitUntil(_ element: XCUIElement,
                           matches format: String,
                           argument: Any? = nil,
                           timeout: TimeInterval) -> Bool {
        let predicate = argument.map { NSPredicate(format: format, argumentArray: [$0]) }
            ?? NSPredicate(format: format)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

// MARK: - ElementType → XCUIElement.ElementType

extension ElementType {
    var xcuiType: XCUIElement.ElementType {
        switch self {
        case .anyElement:          return .any
        case .other:               return .other
        case .group:               return .group
        case .window:              return .window
        case .button:              return .button
        case .link:                return .link
        case .toggleSwitch:        return .`switch`
        case .checkBox:            return .checkBox
        case .radioButton:         return .radioButton
        case .radioGroup:          return .radioGroup
        case .slider:              return .slider
        case .stepper:             return .stepper
        case .segmentedControl:    return .segmentedControl
        case .picker:              return .picker
        case .pickerWheel:         return .pickerWheel
        case .datePicker:          return .datePicker
        case .popUpButton:         return .popUpButton
        case .comboBox:            return .comboBox
        case .menuButton:          return .menuButton
        case .toolbarButton:       return .toolbarButton
        case .disclosureTriangle:  return .disclosureTriangle
        case .incrementArrow:      return .incrementArrow
        case .decrementArrow:      return .decrementArrow
        case .colorWell:           return .colorWell
        case .handle:              return .handle
        case .staticText:          return .staticText
        case .textField:           return .textField
        case .secureTextField:     return .secureTextField
        case .searchField:         return .searchField
        case .textView:            return .textView
        case .image:               return .image
        case .icon:                return .icon
        case .map:                 return .map
        case .webView:             return .webView
        case .cell:                return .cell
        case .table:               return .table
        case .tableRow:            return .tableRow
        case .tableColumn:         return .tableColumn
        case .collectionView:      return .collectionView
        case .scrollView:          return .scrollView
        case .scrollBar:           return .scrollBar
        case .outline:             return .outline
        case .outlineRow:          return .outlineRow
        case .browser:             return .browser
        case .grid:                return .grid
        case .splitGroup:          return .splitGroup
        case .splitter:            return .splitter
        case .layoutArea:          return .layoutArea
        case .layoutItem:          return .layoutItem
        case .matte:               return .matte
        case .navigationBar:       return .navigationBar
        case .tabBar:              return .tabBar
        case .tab:                 return .tab
        case .tabGroup:            return .tabGroup
        case .toolbar:             return .toolbar
        case .statusBar:           return .statusBar
        case .menuBar:             return .menuBar
        case .menuBarItem:         return .menuBarItem
        case .menu:                return .menu
        case .menuItem:            return .menuItem
        case .keyboard:            return .keyboard
        case .key:                 return .key
        case .touchBar:            return .touchBar
        case .statusItem:          return .statusItem
        case .dockItem:            return .dockItem
        case .alert:               return .alert
        case .sheet:               return .sheet
        case .dialog:              return .dialog
        case .popover:             return .popover
        case .drawer:              return .drawer
        case .helpTag:             return .helpTag
        case .activityIndicator:   return .activityIndicator
        case .progressIndicator:   return .progressIndicator
        case .pageIndicator:       return .pageIndicator
        case .levelIndicator:      return .levelIndicator
        case .ratingIndicator:     return .ratingIndicator
        case .relevanceIndicator:  return .relevanceIndicator
        case .valueIndicator:      return .valueIndicator
        case .timeline:            return .timeline
        case .ruler:               return .ruler
        case .rulerMarker:         return .rulerMarker
        }
    }
}
