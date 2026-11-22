//
//  WorkflowContract.swift
//  Shared JSON contract between the Authoring Tool (writer) and the Execution Tool (reader).
//
//  Both Xcode projects compile this same file, so the JSON they exchange can never drift apart.
//
//  Version history
//    1  flat list of action steps, 6 element types, 4 actions
//    2  every XCUIElement type, more actions (gestures, swipes, slider, picker, clear text),
//       verify conditions (exists / notExists / equals / contains / enabled / …), per-step timeout,
//       "if" steps with nested "then" / "else" step lists, and "loop" steps that repeat
//       their nested "steps" N times ("repeatCount").
//       Version 1 files are still read unchanged.
//

import Foundation

// MARK: - Workflow

struct Workflow: Codable, Equatable {
    /// Bump this when the JSON format changes in a non-backwards-compatible way.
    static let currentVersion = 2

    var version: Int
    var name: String
    /// Bundle identifier of the iOS app under test (can be overridden at run time).
    var bundleIdentifier: String?
    var steps: [AutomationStep]

    init(version: Int = Workflow.currentVersion,
         name: String,
         bundleIdentifier: String? = nil,
         steps: [AutomationStep]) {
        self.version = version
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.steps = steps
    }

    /// Number of steps including the ones nested inside if / else blocks.
    var totalStepCount: Int { steps.reduce(0) { $0 + 1 + $1.descendantCount } }
}

// MARK: - Element types (one per XCUIElement.ElementType)

/// Raw values are the names of the matching `XCUIElement.ElementType` cases, so the JSON reads
/// exactly like XCUITest ("button", "staticText", "pickerWheel", …).
enum ElementType: String, Codable, CaseIterable, Identifiable {
    // Generic
    case anyElement = "any"
    case other
    case group
    case window
    // Controls
    case button
    case link
    case toggleSwitch = "switch"
    case checkBox
    case radioButton
    case radioGroup
    case slider
    case stepper
    case segmentedControl
    case picker
    case pickerWheel
    case datePicker
    case popUpButton
    case comboBox
    case menuButton
    case toolbarButton
    case disclosureTriangle
    case incrementArrow
    case decrementArrow
    case colorWell
    case handle
    // Text
    case staticText
    case textField
    case secureTextField
    case searchField
    case textView
    // Images & media
    case image
    case icon
    case map
    case webView
    // Lists & containers
    case cell
    case table
    case tableRow
    case tableColumn
    case collectionView
    case scrollView
    case scrollBar
    case outline
    case outlineRow
    case browser
    case grid
    case splitGroup
    case splitter
    case layoutArea
    case layoutItem
    case matte
    // Navigation & bars
    case navigationBar
    case tabBar
    case tab
    case tabGroup
    case toolbar
    case statusBar
    case menuBar
    case menuBarItem
    case menu
    case menuItem
    case keyboard
    case key
    case touchBar
    case statusItem
    case dockItem
    // Alerts & popups
    case alert
    case sheet
    case dialog
    case popover
    case drawer
    case helpTag
    // Indicators
    case activityIndicator
    case progressIndicator
    case pageIndicator
    case levelIndicator
    case ratingIndicator
    case relevanceIndicator
    case valueIndicator
    case timeline
    case ruler
    case rulerMarker

    var id: String { rawValue }

    // MARK: Behaviour groups

    var isTextInput: Bool {
        [.textField, .secureTextField, .searchField, .textView, .comboBox].contains(self)
    }

    var isToggleable: Bool {
        [.toggleSwitch, .checkBox, .radioButton, .disclosureTriangle].contains(self)
    }

    var isPicker: Bool {
        [.picker, .pickerWheel, .datePicker].contains(self)
    }

    var isScrollable: Bool {
        [.scrollView, .table, .collectionView, .webView, .map, .outline, .browser, .grid].contains(self)
    }

    /// Elements that are normally read, not operated (their default action is `verify`).
    var isDisplayOnly: Bool {
        [.staticText, .image, .icon, .alert, .sheet, .dialog, .drawer, .helpTag,
         .activityIndicator, .progressIndicator, .levelIndicator, .ratingIndicator,
         .relevanceIndicator, .valueIndicator, .timeline, .ruler, .rulerMarker,
         .navigationBar, .statusBar, .menuBar, .touchBar, .keyboard,
         .window, .group, .other, .anyElement, .matte, .splitGroup, .layoutArea,
         .radioGroup, .tabGroup, .tableColumn].contains(self)
    }

    /// Value-bearing elements: their text is `XCUIElement.value` rather than `label`.
    var readsValue: Bool {
        isTextInput || isToggleable || isPicker ||
            [.slider, .stepper, .segmentedControl, .pageIndicator, .progressIndicator,
             .levelIndicator, .ratingIndicator, .valueIndicator, .popUpButton].contains(self)
    }

    var defaultAction: ActionType {
        if isTextInput { return .typeText }
        if isToggleable { return .toggle }
        if self == .slider { return .adjustSlider }
        if isPicker { return .selectPickerValue }
        if isScrollable { return .swipeUp }
        if isDisplayOnly { return .verify }
        return .tap
    }

    /// Actions an element of this type can perform. The first one is the default.
    var supportedActions: [ActionType] {
        let available = ActionType.allCases.filter { action in
            switch action {
            case .typeText, .clearText: return isTextInput
            case .toggle:               return isToggleable
            case .adjustSlider:         return self == .slider
            case .selectPickerValue:    return isPicker
            default:                    return true
            }
        }
        return [defaultAction] + available.filter { $0 != defaultAction }
    }

    /// Check for a new verify / if step on this element (pick Text Equals etc. in the editor).
    var defaultCondition: ConditionType { .exists }
}

// MARK: - Actions

enum ActionType: String, Codable, CaseIterable, Identifiable {
    case tap
    case doubleTap
    case longPress          // value: seconds (optional, default 1)
    case twoFingerTap
    case typeText           // value: text to type (existing text is cleared first)
    case clearText
    case toggle
    case adjustSlider       // value: normalized position 0…1
    case selectPickerValue  // value: picker wheel value
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case verify             // checks `condition` (default: equals if value, else exists)

    var id: String { rawValue }

    var requiresValue: Bool {
        self == .typeText || self == .adjustSlider || self == .selectPickerValue
    }
}

// MARK: - Conditions (used by `verify` steps and `if` steps)

enum ConditionType: String, Codable, CaseIterable, Identifiable {
    case exists
    case notExists
    case equals        // element text == value
    case contains      // element text contains value
    case enabled
    case disabled
    case selected      // also "switch is on" for switches / check boxes
    case notSelected
    case hittable

    var id: String { rawValue }

    var needsValue: Bool { self == .equals || self == .contains }
}

// MARK: - Step

enum StepKind: String, Codable, CaseIterable, Identifiable {
    case action
    case ifElse = "if"
    case loop

    var id: String { rawValue }
}

struct StepPosition: Codable, Equatable {
    var x: Double
    var y: Double
}

/// One step. `kind` decides how it runs:
///  - `action` (default): perform `action` on the element (`type` + `identifier`).
///  - `if`: evaluate `condition` on the element, then run `then` or `else`.
///  - `loop`: run `steps` `repeatCount` times (a loop has no element; `type` / `identifier` are omitted).
struct AutomationStep: Codable, Equatable, Identifiable {
    var id: String
    var kind: StepKind?             // nil -> .action
    var type: ElementType
    var identifier: String          // accessibility identifier in the app under test
    var action: ActionType?         // nil -> type.defaultAction (action steps only)
    var condition: ConditionType?   // verify / if check; see `resolvedCondition`
    var value: String?              // text to type, expected text, slider position, …
    var timeout: Double?            // seconds to wait for the element / condition
    var waitTime: Double?           // seconds to pause after the step succeeds
    var thenSteps: [AutomationStep]?
    var elseSteps: [AutomationStep]?
    var repeatCount: Int?           // loop steps: how many times to run `loopSteps`
    var loopSteps: [AutomationStep]?
    var position: StepPosition?     // editor layout only (ignored by the executor)
    var label: String?              // step name shown in the editor (ignored by the executor)
    var collapsed: Bool?            // editor only: block shown minimized (ignored by the executor)
    var enabled: Bool?              // nil == true; disabled steps are skipped

    enum CodingKeys: String, CodingKey {
        case id, kind, type, identifier, action, condition, value, timeout, waitTime
        case thenSteps = "then"
        case elseSteps = "else"
        case repeatCount
        case loopSteps = "steps"
        case position, label, collapsed, enabled
    }

    init(id: String,
         kind: StepKind? = nil,
         type: ElementType,
         identifier: String,
         action: ActionType? = nil,
         condition: ConditionType? = nil,
         value: String? = nil,
         timeout: Double? = nil,
         waitTime: Double? = nil,
         thenSteps: [AutomationStep]? = nil,
         elseSteps: [AutomationStep]? = nil,
         repeatCount: Int? = nil,
         loopSteps: [AutomationStep]? = nil,
         position: StepPosition? = nil,
         label: String? = nil,
         collapsed: Bool? = nil,
         enabled: Bool? = nil) {
        self.id = id
        self.kind = kind
        self.type = type
        self.identifier = identifier
        self.action = action
        self.condition = condition
        self.value = value
        self.timeout = timeout
        self.waitTime = waitTime
        self.thenSteps = thenSteps
        self.elseSteps = elseSteps
        self.repeatCount = repeatCount
        self.loopSteps = loopSteps
        self.position = position
        self.label = label
        self.collapsed = collapsed
        self.enabled = enabled
    }

    /// A loop step (no element).
    static func loop(id: String, repeatCount: Int, steps: [AutomationStep], label: String? = nil) -> AutomationStep {
        AutomationStep(id: id, kind: .loop, type: .anyElement, identifier: "",
                       repeatCount: repeatCount, loopSteps: steps, label: label)
    }

    // MARK: Codable (loops have no type / identifier in the JSON)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decodeIfPresent(StepKind.self, forKey: .kind)
        if kind == .loop {
            type = try c.decodeIfPresent(ElementType.self, forKey: .type) ?? .anyElement
            identifier = try c.decodeIfPresent(String.self, forKey: .identifier) ?? ""
        } else {
            type = try c.decode(ElementType.self, forKey: .type)
            identifier = try c.decode(String.self, forKey: .identifier)
        }
        action = try c.decodeIfPresent(ActionType.self, forKey: .action)
        condition = try c.decodeIfPresent(ConditionType.self, forKey: .condition)
        value = try c.decodeIfPresent(String.self, forKey: .value)
        timeout = try c.decodeIfPresent(Double.self, forKey: .timeout)
        waitTime = try c.decodeIfPresent(Double.self, forKey: .waitTime)
        thenSteps = try c.decodeIfPresent([AutomationStep].self, forKey: .thenSteps)
        elseSteps = try c.decodeIfPresent([AutomationStep].self, forKey: .elseSteps)
        repeatCount = try c.decodeIfPresent(Int.self, forKey: .repeatCount)
        loopSteps = try c.decodeIfPresent([AutomationStep].self, forKey: .loopSteps)
        position = try c.decodeIfPresent(StepPosition.self, forKey: .position)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(kind, forKey: .kind)
        if !isLoop {
            try c.encode(type, forKey: .type)
            try c.encode(identifier, forKey: .identifier)
        }
        try c.encodeIfPresent(action, forKey: .action)
        try c.encodeIfPresent(condition, forKey: .condition)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encodeIfPresent(timeout, forKey: .timeout)
        try c.encodeIfPresent(waitTime, forKey: .waitTime)
        try c.encodeIfPresent(thenSteps, forKey: .thenSteps)
        try c.encodeIfPresent(elseSteps, forKey: .elseSteps)
        try c.encodeIfPresent(repeatCount, forKey: .repeatCount)
        try c.encodeIfPresent(loopSteps, forKey: .loopSteps)
        try c.encodeIfPresent(position, forKey: .position)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(collapsed, forKey: .collapsed)
        try c.encodeIfPresent(enabled, forKey: .enabled)
    }

    var resolvedKind: StepKind { kind ?? .action }
    var resolvedAction: ActionType { action ?? type.defaultAction }
    /// Explicit condition, else "equals" when a value is given, else "exists" (version 1 behaviour).
    var resolvedCondition: ConditionType { condition ?? (value != nil ? .equals : .exists) }
    var isEnabled: Bool { enabled ?? true }
    var isIf: Bool { resolvedKind == .ifElse }
    var isLoop: Bool { resolvedKind == .loop }
    var resolvedRepeatCount: Int { repeatCount ?? 1 }

    /// Every nested step (then + else + loop body).
    var children: [AutomationStep] { (thenSteps ?? []) + (elseSteps ?? []) + (loopSteps ?? []) }

    var descendantCount: Int {
        children.reduce(0) { $0 + 1 + $1.descendantCount }
    }
}

// MARK: - Errors

enum WorkflowError: LocalizedError, Equatable {
    case unsupportedVersion(found: Int, supported: Int)
    case duplicateStepID(String)
    case emptyIdentifier(stepID: String)
    case unsupportedAction(stepID: String, type: ElementType, action: ActionType)
    case missingValue(stepID: String, what: String)
    case invalidValue(stepID: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(found, supported):
            return "Workflow version \(found) is not supported (this tool supports up to version \(supported))."
        case let .duplicateStepID(id):
            return "Step id '\(id)' is used more than once."
        case let .emptyIdentifier(stepID):
            return "Step \(stepID) has an empty accessibility identifier."
        case let .unsupportedAction(stepID, type, action):
            return "Step \(stepID): action '\(action.rawValue)' is not supported for '\(type.rawValue)'."
        case let .missingValue(stepID, what):
            return "Step \(stepID): '\(what)' needs a value."
        case let .invalidValue(stepID, message):
            return "Step \(stepID): \(message)"
        }
    }
}

// MARK: - Codec (encode / decode / validate)

enum WorkflowCodec {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func encode(_ workflow: Workflow) throws -> Data {
        try makeEncoder().encode(workflow)
    }

    static func decode(_ data: Data) throws -> Workflow {
        let workflow = try JSONDecoder().decode(Workflow.self, from: data)
        try validate(workflow)
        return workflow
    }

    static func validate(_ workflow: Workflow) throws {
        guard (1...Workflow.currentVersion).contains(workflow.version) else {
            throw WorkflowError.unsupportedVersion(found: workflow.version, supported: Workflow.currentVersion)
        }
        var seen = Set<String>()
        try validate(workflow.steps, seen: &seen)
    }

    private static func validate(_ steps: [AutomationStep], seen: inout Set<String>) throws {
        for step in steps {
            guard seen.insert(step.id).inserted else {
                throw WorkflowError.duplicateStepID(step.id)
            }
            guard step.isLoop || !step.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WorkflowError.emptyIdentifier(stepID: step.id)
            }
            if let timeout = step.timeout, timeout < 0 {
                throw WorkflowError.invalidValue(stepID: step.id, message: "timeout must not be negative.")
            }

            switch step.resolvedKind {
            case .action:
                let action = step.resolvedAction
                guard step.type.supportedActions.contains(action) else {
                    throw WorkflowError.unsupportedAction(stepID: step.id, type: step.type, action: action)
                }
                if action.requiresValue && step.value == nil {
                    throw WorkflowError.missingValue(stepID: step.id, what: action.rawValue)
                }
                if action == .verify && step.resolvedCondition.needsValue && step.value == nil {
                    throw WorkflowError.missingValue(stepID: step.id, what: "verify \(step.resolvedCondition.rawValue)")
                }
                if action == .adjustSlider {
                    guard let v = step.value.flatMap(Double.init), (0...1).contains(v) else {
                        throw WorkflowError.invalidValue(stepID: step.id,
                                                         message: "adjustSlider needs a value between 0 and 1.")
                    }
                }
                if action == .longPress, let raw = step.value, !raw.isEmpty {
                    guard let v = Double(raw), v > 0 else {
                        throw WorkflowError.invalidValue(stepID: step.id,
                                                         message: "longPress value must be a duration in seconds.")
                    }
                }

            case .ifElse:
                if step.resolvedCondition.needsValue && step.value == nil {
                    throw WorkflowError.missingValue(stepID: step.id, what: "if \(step.resolvedCondition.rawValue)")
                }
                try validate(step.thenSteps ?? [], seen: &seen)
                try validate(step.elseSteps ?? [], seen: &seen)

            case .loop:
                guard let count = step.repeatCount, (1...10_000).contains(count) else {
                    throw WorkflowError.invalidValue(stepID: step.id,
                                                     message: "loop needs a repeatCount between 1 and 10000.")
                }
                try validate(step.loopSteps ?? [], seen: &seen)
            }
        }
    }
}
