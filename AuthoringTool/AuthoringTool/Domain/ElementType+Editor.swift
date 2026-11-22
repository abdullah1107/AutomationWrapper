//
//  ElementType+Editor.swift
//  Editor-only presentation details for the shared contract types,
//  palette categories and drag & drop payloads.
//

import Foundation

// MARK: - Palette categories

enum ElementCategory: String, CaseIterable, Identifiable {
    case common     = "Common"
    case controls   = "Controls"
    case text       = "Text"
    case media      = "Images & Media"
    case containers = "Lists & Containers"
    case navigation = "Navigation & Bars"
    case popups     = "Alerts & Popups"
    case indicators = "Indicators"
    case generic    = "Generic"

    var id: String { rawValue }

    /// The element types listed under this category (Common repeats the most used ones).
    var types: [ElementType] {
        if self == .common {
            return [.button, .staticText, .textField, .secureTextField, .toggleSwitch,
                    .image, .cell, .alert, .navigationBar, .scrollView]
        }
        return ElementType.allCases.filter { $0.category == self }
    }

    /// Categories where every type appears exactly once (for pickers).
    static var exclusive: [ElementCategory] { allCases.filter { $0 != .common } }
}

extension ElementType {
    var category: ElementCategory {
        switch self {
        case .anyElement, .other, .group, .window:
            return .generic
        case .button, .link, .toggleSwitch, .checkBox, .radioButton, .radioGroup, .slider, .stepper,
             .segmentedControl, .picker, .pickerWheel, .datePicker, .popUpButton, .comboBox,
             .menuButton, .toolbarButton, .disclosureTriangle, .incrementArrow, .decrementArrow,
             .colorWell, .handle:
            return .controls
        case .staticText, .textField, .secureTextField, .searchField, .textView:
            return .text
        case .image, .icon, .map, .webView:
            return .media
        case .cell, .table, .tableRow, .tableColumn, .collectionView, .scrollView, .scrollBar,
             .outline, .outlineRow, .browser, .grid, .splitGroup, .splitter, .layoutArea,
             .layoutItem, .matte:
            return .containers
        case .navigationBar, .tabBar, .tab, .tabGroup, .toolbar, .statusBar, .menuBar, .menuBarItem,
             .menu, .menuItem, .keyboard, .key, .touchBar, .statusItem, .dockItem:
            return .navigation
        case .alert, .sheet, .dialog, .popover, .drawer, .helpTag:
            return .popups
        case .activityIndicator, .progressIndicator, .pageIndicator, .levelIndicator, .ratingIndicator,
             .relevanceIndicator, .valueIndicator, .timeline, .ruler, .rulerMarker:
            return .indicators
        }
    }

    var displayName: String {
        switch self {
        case .anyElement:      return "Any Element"
        case .staticText:      return "Static Text (Label)"
        case .secureTextField: return "Secure Text Field"
        case .toggleSwitch:    return "Switch"
        case .webView:         return "Web View"
        default:               return rawValue.splitCamelCase(separator: " ").capitalizedFirstLetters
        }
    }

    var systemImage: String {
        switch self {
        case .anyElement:          return "questionmark.square.dashed"
        case .other:               return "square.dashed"
        case .group:               return "square.stack"
        case .window:              return "macwindow"
        case .button:              return "rectangle.fill"
        case .link:                return "link"
        case .toggleSwitch:        return "switch.2"
        case .checkBox:            return "checkmark.square"
        case .radioButton:         return "largecircle.fill.circle"
        case .radioGroup:          return "list.bullet.circle"
        case .slider:              return "slider.horizontal.3"
        case .stepper:             return "plusminus"
        case .segmentedControl:    return "rectangle.split.3x1"
        case .picker:              return "filemenu.and.selection"
        case .pickerWheel:         return "dial.min"
        case .datePicker:          return "calendar"
        case .popUpButton:         return "chevron.up.chevron.down"
        case .comboBox:            return "list.bullet.rectangle"
        case .menuButton:          return "ellipsis.circle"
        case .toolbarButton:       return "hammer"
        case .disclosureTriangle:  return "chevron.right"
        case .incrementArrow:      return "arrowtriangle.up"
        case .decrementArrow:      return "arrowtriangle.down"
        case .colorWell:           return "paintpalette"
        case .handle:              return "line.3.horizontal"
        case .staticText:          return "textformat"
        case .textField:           return "character.cursor.ibeam"
        case .secureTextField:     return "key.fill"
        case .searchField:         return "magnifyingglass"
        case .textView:            return "text.alignleft"
        case .image:               return "photo"
        case .icon:                return "app"
        case .map:                 return "map"
        case .webView:             return "globe"
        case .cell:                return "rectangle.grid.1x2"
        case .table:               return "list.bullet"
        case .tableRow:            return "list.dash"
        case .tableColumn:         return "tablecells"
        case .collectionView:      return "square.grid.2x2"
        case .scrollView:          return "scroll"
        case .scrollBar:           return "arrow.up.and.down"
        case .outline:             return "list.bullet.indent"
        case .outlineRow:          return "increase.indent"
        case .browser:             return "sidebar.left"
        case .grid:                return "square.grid.3x3"
        case .splitGroup:          return "rectangle.split.2x1"
        case .splitter:            return "divide"
        case .layoutArea:          return "rectangle.dashed"
        case .layoutItem:          return "square.dashed.inset.filled"
        case .matte:               return "rectangle.fill.on.rectangle.fill"
        case .navigationBar:       return "menubar.rectangle"
        case .tabBar:              return "dock.rectangle"
        case .tab:                 return "rectangle.on.rectangle"
        case .tabGroup:            return "rectangle.stack"
        case .toolbar:             return "wrench.and.screwdriver"
        case .statusBar:           return "wifi"
        case .menuBar:             return "menubar.dock.rectangle"
        case .menuBarItem:         return "filemenu.and.cursorarrow"
        case .menu:                return "contextualmenu.and.cursorarrow"
        case .menuItem:            return "text.badge.checkmark"
        case .keyboard:            return "keyboard"
        case .key:                 return "command"
        case .touchBar:            return "slider.horizontal.below.rectangle"
        case .statusItem:          return "menubar.arrow.up.rectangle"
        case .dockItem:            return "dock.arrow.up.rectangle"
        case .alert:               return "exclamationmark.triangle"
        case .sheet:               return "rectangle.bottomhalf.inset.filled"
        case .dialog:              return "text.bubble"
        case .popover:             return "bubble.middle.bottom"
        case .drawer:              return "sidebar.right"
        case .helpTag:             return "questionmark.bubble"
        case .activityIndicator:   return "rays"
        case .progressIndicator:   return "hourglass"
        case .pageIndicator:       return "ellipsis"
        case .levelIndicator:      return "gauge"
        case .ratingIndicator:     return "star"
        case .relevanceIndicator:  return "chart.bar"
        case .valueIndicator:      return "number"
        case .timeline:            return "clock"
        case .ruler:               return "ruler"
        case .rulerMarker:         return "arrowtriangle.down.fill"
        }
    }

    var defaultDisplayText: String {
        switch self {
        case .textField:       return "Enter text"
        case .secureTextField: return "Enter password"
        case .searchField:     return "Search"
        case .staticText:      return "Label"
        case .anyElement:      return "Element"
        default:               return displayName
        }
    }

    var identifierPrefix: String {
        switch self {
        case .staticText:      return "label"
        case .secureTextField: return "secure_field"
        case .anyElement:      return "element"
        default:               return rawValue.splitCamelCase(separator: "_").lowercased()
        }
    }

    func matches(search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return displayName.lowercased().contains(query) || rawValue.lowercased().contains(query)
    }

    // MARK: Drag & drop payload (kept for compatibility; see DragItem)

    var dragPayload: String { DragItem.element(self).payload }

    init?(dragPayload: String) {
        guard case let .element(type)? = DragItem(payload: dragPayload) else { return nil }
        self = type
    }
}

extension ActionType {
    var displayName: String {
        switch self {
        case .tap:               return "Tap"
        case .doubleTap:         return "Double Tap"
        case .longPress:         return "Long Press"
        case .twoFingerTap:      return "Two-Finger Tap"
        case .typeText:          return "Type Text"
        case .clearText:         return "Clear Text"
        case .toggle:            return "Toggle"
        case .adjustSlider:      return "Adjust Slider"
        case .selectPickerValue: return "Select Picker Value"
        case .swipeUp:           return "Swipe Up"
        case .swipeDown:         return "Swipe Down"
        case .swipeLeft:         return "Swipe Left"
        case .swipeRight:        return "Swipe Right"
        case .verify:            return "Verify"
        }
    }
}

extension ConditionType {
    var displayName: String {
        switch self {
        case .exists:      return "Exists"
        case .notExists:   return "Does Not Exist"
        case .equals:      return "Text Equals"
        case .contains:    return "Text Contains"
        case .enabled:     return "Is Enabled"
        case .disabled:    return "Is Disabled"
        case .selected:    return "Is Selected / On"
        case .notSelected: return "Is Not Selected / Off"
        case .hittable:    return "Is Hittable"
        }
    }
}

// MARK: - Drag & drop

/// Everything that can be dragged inside the editor, encoded as a plain string.
enum DragItem: Equatable {
    case element(ElementType)   // new action step from the palette
    case ifBlock                // new If / Else block from the palette
    case loopBlock              // new Loop block from the palette
    case step(UUID)             // an existing step being moved

    private static let elementPrefix = "automation-element:"
    private static let ifBlockPayload = "automation-block:if"
    private static let loopBlockPayload = "automation-block:loop"
    private static let stepPrefix = "automation-step:"

    var payload: String {
        switch self {
        case let .element(type): return DragItem.elementPrefix + type.rawValue
        case .ifBlock:           return DragItem.ifBlockPayload
        case .loopBlock:         return DragItem.loopBlockPayload
        case let .step(id):      return DragItem.stepPrefix + id.uuidString
        }
    }

    init?(payload: String) {
        if payload == DragItem.ifBlockPayload {
            self = .ifBlock
        } else if payload == DragItem.loopBlockPayload {
            self = .loopBlock
        } else if payload.hasPrefix(DragItem.elementPrefix),
                  let type = ElementType(rawValue: String(payload.dropFirst(DragItem.elementPrefix.count))) {
            self = .element(type)
        } else if payload.hasPrefix(DragItem.stepPrefix),
                  let id = UUID(uuidString: String(payload.dropFirst(DragItem.stepPrefix.count))) {
            self = .step(id)
        } else {
            return nil
        }
    }
}

// MARK: - String helpers

private extension String {
    /// "pickerWheel" -> "picker Wheel" / "picker_Wheel"
    func splitCamelCase(separator: String) -> String {
        var result = ""
        for character in self {
            if character.isUppercase && !result.isEmpty { result += separator }
            result.append(character)
        }
        return result
    }

    var capitalizedFirstLetters: String {
        split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
