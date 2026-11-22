//
//  UIElement.swift
//  Domain model for one step in the editor (no layout: only order matters).
//  A step is one of:
//    • an action on an element
//    • an If / Else block that verifies an element and holds nested THEN / ELSE steps
//    • a Loop block that repeats its nested steps N times
//  The order of a step list is its execution order. Every step has a name (displayText,
//  saved as "label") that can be renamed, and blocks can be collapsed in the editor.
//

import Foundation

enum Branch: String, CaseIterable {
    case thenBranch
    case elseBranch
    case loopBody

    var title: String {
        switch self {
        case .thenBranch: return "THEN"
        case .elseBranch: return "ELSE"
        case .loopBody:   return "DO"
        }
    }

    /// Used in step ids: "3.T1", "3.E1", "3.L1".
    var idMarker: String {
        switch self {
        case .thenBranch: return "T"
        case .elseBranch: return "E"
        case .loopBody:   return "L"
        }
    }
}

/// Where a step sits in the tree: inside `parentID`'s branch (or the root list if nil), at `index`.
struct StepLocation: Equatable {
    var parentID: UUID?
    var branch: Branch = .thenBranch     // ignored for the root list
    var index: Int

    static func root(_ index: Int) -> StepLocation { StepLocation(parentID: nil, index: index) }
}

struct UIElement: Identifiable, Equatable {
    var id: UUID
    var kind: StepKind
    var type: ElementType {
        didSet {
            // Keep the action valid when the element type changes in the inspector.
            if !type.supportedActions.contains(action) { action = type.defaultAction }
        }
    }
    var identifier: String
    /// The step's name, shown in the design area. Renamable. Saved as "label".
    var displayText: String
    var action: ActionType {
        didSet {
            if action == .verify && oldValue != .verify { condition = type.defaultCondition }
        }
    }
    /// Check used by verify actions and If / Else blocks.
    var condition: ConditionType
    var value: String
    /// Seconds to wait for the element / condition; 0 = executor default.
    var timeout: Double
    var waitTime: Double
    var enabled: Bool
    var thenSteps: [UIElement]
    var elseSteps: [UIElement]
    /// Loop blocks: how many times the body runs.
    var repeatCount: Int
    var loopSteps: [UIElement]
    /// Editor only: block shown minimized.
    var isCollapsed: Bool

    init(id: UUID = UUID(),
         kind: StepKind = .action,
         type: ElementType,
         identifier: String,
         displayText: String,
         action: ActionType? = nil,
         condition: ConditionType? = nil,
         value: String = "",
         timeout: Double = 0,
         waitTime: Double = 1,
         enabled: Bool = true,
         thenSteps: [UIElement] = [],
         elseSteps: [UIElement] = [],
         repeatCount: Int = 3,
         loopSteps: [UIElement] = [],
         isCollapsed: Bool = false) {
        self.id = id
        self.kind = kind
        self.type = type
        self.identifier = identifier
        self.displayText = displayText
        self.action = action ?? type.defaultAction
        self.condition = condition ?? type.defaultCondition
        self.value = value
        self.timeout = timeout
        self.waitTime = waitTime
        self.enabled = enabled
        self.thenSteps = thenSteps
        self.elseSteps = elseSteps
        self.repeatCount = repeatCount
        self.loopSteps = loopSteps
        self.isCollapsed = isCollapsed
    }

    static func make(type: ElementType, identifier: String) -> UIElement {
        UIElement(type: type,
                  identifier: identifier,
                  displayText: type.defaultDisplayText)
    }

    /// A new If / Else block. Its condition checks the element `type` + `identifier`.
    static func makeIf(type: ElementType = .anyElement,
                       identifier: String,
                       displayText: String = "If / Else") -> UIElement {
        UIElement(kind: .ifElse,
                  type: type,
                  identifier: identifier,
                  displayText: displayText,
                  condition: .exists,
                  waitTime: 0)
    }

    /// A new Loop block (repeat N times).
    static func makeLoop(repeatCount: Int = 3, displayText: String = "Loop") -> UIElement {
        UIElement(kind: .loop,
                  type: .anyElement,
                  identifier: "",
                  displayText: displayText,
                  waitTime: 0,
                  repeatCount: repeatCount)
    }

    /// Used by the inspector binding when the selected element was just removed.
    static let placeholder = UIElement(type: .button, identifier: "", displayText: "")

    var isIf: Bool { kind == .ifElse }
    var isLoop: Bool { kind == .loop }
    /// If / Else or Loop: holds nested steps.
    var isBlock: Bool { isIf || isLoop }

    /// The nested step lists of this step, in display order.
    var branches: [Branch] {
        switch kind {
        case .action: return []
        case .ifElse: return [.thenBranch, .elseBranch]
        case .loop:   return [.loopBody]
        }
    }

    var nestedCount: Int { branches.reduce(0) { $0 + children($1).count } }

    var usesValue: Bool {
        if isLoop { return false }
        if isIf { return condition.needsValue }
        switch action {
        case .typeText, .longPress, .adjustSlider, .selectPickerValue: return true
        case .verify: return condition.needsValue
        default: return false
        }
    }

    func children(_ branch: Branch) -> [UIElement] {
        switch branch {
        case .thenBranch: return thenSteps
        case .elseBranch: return elseSteps
        case .loopBody:   return loopSteps
        }
    }

    mutating func setChildren(_ steps: [UIElement], _ branch: Branch) {
        switch branch {
        case .thenBranch: thenSteps = steps
        case .elseBranch: elseSteps = steps
        case .loopBody:   loopSteps = steps
        }
    }

    /// Deep copy with fresh ids (for Duplicate).
    func duplicated() -> UIElement {
        var copy = self
        copy.id = UUID()
        copy.thenSteps = thenSteps.map { $0.duplicated() }
        copy.elseSteps = elseSteps.map { $0.duplicated() }
        copy.loopSteps = loopSteps.map { $0.duplicated() }
        return copy
    }

    // MARK: Mapping to / from the JSON contract

    static func childID(parent: String, branch: Branch, index: Int) -> String {
        "\(parent).\(branch.idMarker)\(index + 1)"
    }

    /// Expected text for verify / if (the step name is never used as expected text).
    private var expectedText: String { value }

    private func childSteps(_ branch: Branch, id: String) -> [AutomationStep] {
        children(branch).enumerated().map { index, step in
            step.toStep(id: Self.childID(parent: id, branch: branch, index: index))
        }
    }

    func toStep(id: String) -> AutomationStep {
        if isLoop {
            return AutomationStep(id: id,
                                  kind: .loop,
                                  type: .anyElement,
                                  identifier: "",
                                  waitTime: waitTime > 0 ? waitTime : nil,
                                  repeatCount: max(1, repeatCount),
                                  loopSteps: childSteps(.loopBody, id: id),
                                  label: displayText,
                                  collapsed: isCollapsed ? true : nil,
                                  enabled: enabled ? nil : false)
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var stepValue: String?
        var stepCondition: ConditionType?

        if isIf {
            stepCondition = condition
            stepValue = condition.needsValue ? expectedText : nil
        } else {
            switch action {
            case .typeText, .selectPickerValue:
                stepValue = value
            case .adjustSlider:
                stepValue = trimmed
            case .longPress:
                stepValue = trimmed.isEmpty ? nil : trimmed
            case .verify:
                stepCondition = condition
                stepValue = condition.needsValue ? expectedText : nil
            default:
                stepValue = nil
            }
        }

        return AutomationStep(
            id: id,
            kind: isIf ? .ifElse : nil,
            type: type,
            identifier: identifier,
            action: isIf ? nil : action,
            condition: stepCondition,
            value: stepValue,
            timeout: timeout > 0 ? timeout : nil,
            waitTime: waitTime,
            thenSteps: isIf ? childSteps(.thenBranch, id: id) : nil,
            elseSteps: isIf ? childSteps(.elseBranch, id: id) : nil,
            label: displayText,
            collapsed: (isIf && isCollapsed) ? true : nil,
            enabled: enabled ? nil : false
        )
    }

    init(step: AutomationStep) {
        let usesCondition = step.isIf || step.resolvedAction == .verify
        let defaultName = step.isLoop ? "Loop" : step.type.defaultDisplayText
        self.init(kind: step.resolvedKind,
                  type: step.type,
                  identifier: step.identifier,
                  displayText: step.label ?? defaultName,
                  action: step.resolvedAction,
                  condition: usesCondition ? step.resolvedCondition : step.type.defaultCondition,
                  value: step.value ?? "",
                  timeout: step.timeout ?? 0,
                  waitTime: step.waitTime ?? 0,
                  enabled: step.isEnabled,
                  thenSteps: (step.thenSteps ?? []).map { UIElement(step: $0) },
                  elseSteps: (step.elseSteps ?? []).map { UIElement(step: $0) },
                  repeatCount: step.repeatCount ?? 3,
                  loopSteps: (step.loopSteps ?? []).map { UIElement(step: $0) },
                  isCollapsed: step.collapsed ?? false)
    }
}

// MARK: - Tree operations

struct NumberedStep {
    let element: UIElement
    let number: String
    let depth: Int
}

extension Array where Element == UIElement {
    func findStep(_ id: UUID) -> UIElement? {
        for step in self {
            if step.id == id { return step }
            for branch in step.branches {
                if let found = step.children(branch).findStep(id) { return found }
            }
        }
        return nil
    }

    func location(of id: UUID, parentID: UUID? = nil, branch: Branch = .thenBranch) -> StepLocation? {
        for (index, step) in enumerated() {
            if step.id == id { return StepLocation(parentID: parentID, branch: branch, index: index) }
            for child in step.branches {
                if let found = step.children(child).location(of: id, parentID: step.id, branch: child) {
                    return found
                }
            }
        }
        return nil
    }

    @discardableResult
    mutating func updateStep(_ id: UUID, _ body: (inout UIElement) -> Void) -> Bool {
        for index in indices {
            if self[index].id == id {
                body(&self[index])
                return true
            }
            for branch in self[index].branches {
                var children = self[index].children(branch)
                if children.updateStep(id, body) {
                    self[index].setChildren(children, branch)
                    return true
                }
            }
        }
        return false
    }

    /// Removes the step (with everything inside it) and returns it with its old location.
    mutating func removeStep(_ id: UUID, parentID: UUID? = nil, branch: Branch = .thenBranch) -> (UIElement, StepLocation)? {
        if let index = firstIndex(where: { $0.id == id }) {
            return (remove(at: index), StepLocation(parentID: parentID, branch: branch, index: index))
        }
        for index in indices {
            let ownerID = self[index].id
            for child in self[index].branches {
                var children = self[index].children(child)
                if let found = children.removeStep(id, parentID: ownerID, branch: child) {
                    self[index].setChildren(children, child)
                    return found
                }
            }
        }
        return nil
    }

    @discardableResult
    mutating func insertStep(_ step: UIElement, at location: StepLocation) -> Bool {
        guard let parentID = location.parentID else {
            insert(step, at: Swift.max(0, Swift.min(location.index, count)))
            return true
        }
        guard let parent = findStep(parentID), parent.branches.contains(location.branch) else { return false }
        return updateStep(parentID) { parent in
            var children = parent.children(location.branch)
            children.insert(step, at: Swift.max(0, Swift.min(location.index, children.count)))
            parent.setChildren(children, location.branch)
        }
    }

    /// Depth-first list of every step with its display number ("3", "3.T1", "3.E2", "4.L1", …).
    func numbered(prefix: String? = nil, branch: Branch? = nil, depth: Int = 0) -> [NumberedStep] {
        var result: [NumberedStep] = []
        for (index, step) in enumerated() {
            let number: String
            if let prefix, let branch {
                number = UIElement.childID(parent: prefix, branch: branch, index: index)
            } else {
                number = String(index + 1)
            }
            result.append(NumberedStep(element: step, number: number, depth: depth))
            for child in step.branches {
                result += step.children(child).numbered(prefix: number, branch: child, depth: depth + 1)
            }
        }
        return result
    }

    var allSteps: [UIElement] {
        flatMap { step in [step] + step.branches.flatMap { step.children($0).allSteps } }
    }
}
