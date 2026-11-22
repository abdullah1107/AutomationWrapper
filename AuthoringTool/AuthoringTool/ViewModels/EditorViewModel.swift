//
//  EditorViewModel.swift
//  Manages the step tree (actions + If / Else blocks), handles drag & drop, updates
//  properties, maintains the execution order, and talks to the repository for save / open.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class EditorViewModel: ObservableObject {
    @Published var workflowName: String = "Untitled Workflow"
    /// Bundle identifier of the app the Execution Tool should drive.
    @Published var bundleIdentifier: String = ""
    /// Root steps. Order == execution order; If / Else blocks hold nested steps.
    @Published var elements: [UIElement] = []
    @Published var selectedID: UUID?
    @Published var currentFileURL: URL?
    @Published var statusMessage: String = "Drag elements from the palette into the sequence. Steps run top to bottom."

    private let repository: WorkflowRepository

    init(repository: WorkflowRepository = WorkflowRepository()) {
        self.repository = repository
        loadLoginSample()
    }

    // MARK: - Queries

    /// Every step, depth-first, with its display number.
    var numberedSteps: [NumberedStep] { elements.numbered() }

    /// Every step including the ones nested in If / Else blocks.
    var allElements: [UIElement] { elements.allSteps }

    var selectedElement: UIElement? {
        guard let selectedID else { return nil }
        return elements.findStep(selectedID)
    }

    /// "3", "3.T1", "3.E2" … (same as the step id written to JSON).
    func stepNumber(of id: UUID) -> String {
        numberedSteps.first { $0.element.id == id }?.number ?? "?"
    }

    func siblingCount(of id: UUID) -> Int {
        guard let location = elements.location(of: id) else { return 0 }
        return siblings(at: location).count
    }

    private func siblings(at location: StepLocation) -> [UIElement] {
        guard let parentID = location.parentID else { return elements }
        return elements.findStep(parentID)?.children(location.branch) ?? []
    }

    /// Binding used by the inspector; safe if the element is deleted while shown.
    func binding(for id: UUID) -> Binding<UIElement> {
        Binding(
            get: { [weak self] in
                self?.elements.findStep(id) ?? .placeholder
            },
            set: { [weak self] newValue in
                self?.elements.updateStep(id) { $0 = newValue }
            }
        )
    }

    // MARK: - Adding steps

    /// Adds a step at the end of the sequence (double-click on the palette).
    @discardableResult
    func addElement(_ type: ElementType) -> UIElement {
        let element = UIElement.make(type: type,
                                     identifier: uniqueIdentifier(prefix: type.identifierPrefix))
        insert(element, at: .root(elements.count))
        return element
    }

    @discardableResult
    func addIfBlock(location: StepLocation? = nil) -> UIElement {
        let block = UIElement.makeIf(identifier: uniqueIdentifier(prefix: ElementType.anyElement.identifierPrefix))
        insert(block, at: location ?? .root(elements.count))
        return block
    }

    @discardableResult
    func addLoopBlock(location: StepLocation? = nil) -> UIElement {
        let block = UIElement.makeLoop()
        insert(block, at: location ?? .root(elements.count))
        return block
    }

    private func insert(_ step: UIElement, at location: StepLocation) {
        guard elements.insertStep(step, at: location) else { return }
        selectedID = step.id
        let what: String
        switch step.kind {
        case .ifElse: what = "If / Else block"
        case .loop:   what = "Loop block"
        case .action: what = "\(step.type.displayName) '\(step.identifier)'"
        }
        statusMessage = "Added \(what) as step \(stepNumber(of: step.id))."
    }

    // MARK: - Drag & drop

    /// Drop of a palette item or an existing step onto a place in the sequence.
    @discardableResult
    func handleDrop(_ payloads: [String], at location: StepLocation) -> Bool {
        guard let item = payloads.lazy.compactMap(DragItem.init(payload:)).first else { return false }
        switch item {
        case let .element(type):
            let element = UIElement.make(type: type,
                                         identifier: uniqueIdentifier(prefix: type.identifierPrefix))
            insert(element, at: location)
            return true
        case .ifBlock:
            addIfBlock(location: location)
            return true
        case .loopBlock:
            addLoopBlock(location: location)
            return true
        case let .step(id):
            return moveStep(id, to: location)
        }
    }

    /// Drop onto an If block's VERIFY slot: the dropped element becomes what the If checks.
    /// A palette element sets the type (with a fresh identifier); an existing step lends its
    /// element (type + identifier) and stays where it is.
    @discardableResult
    func handleConditionDrop(_ payloads: [String], on blockID: UUID) -> Bool {
        guard let item = payloads.lazy.compactMap(DragItem.init(payload:)).first,
              elements.findStep(blockID)?.isIf == true else { return false }
        switch item {
        case let .element(type):
            let identifier = uniqueIdentifier(prefix: type.identifierPrefix)
            elements.updateStep(blockID) { block in
                block.type = type
                block.identifier = identifier
                block.displayText = type.defaultDisplayText
                block.condition = type.defaultCondition
            }
        case let .step(id):
            guard id != blockID, let source = elements.findStep(id) else { return false }
            elements.updateStep(blockID) { block in
                block.type = source.type
                block.identifier = source.identifier
                block.displayText = source.displayText
            }
        case .ifBlock, .loopBlock:
            return false
        }
        selectedID = blockID
        if let block = elements.findStep(blockID) {
            statusMessage = "If \(stepNumber(of: blockID)) now verifies \(block.type.displayName) '\(block.identifier)'."
        }
        return true
    }

    /// Moves a step (and everything inside it) to a new place in the tree.
    @discardableResult
    func moveStep(_ id: UUID, to location: StepLocation) -> Bool {
        if let parentID = location.parentID {
            // A block cannot be dropped into itself or into one of its own branches.
            guard let moving = elements.findStep(id), [moving].findStep(parentID) == nil else {
                statusMessage = "A block can't be moved inside itself."
                return false
            }
        }
        var tree = elements
        guard let removed = tree.removeStep(id) else { return false }
        let (step, old) = removed
        var target = location
        if old.parentID == target.parentID && (old.parentID == nil || old.branch == target.branch)
            && old.index < target.index {
            target.index -= 1
        }
        guard tree.insertStep(step, at: target) else { return false }
        elements = tree
        selectedID = id
        statusMessage = "Moved '\(step.displayText)' to step \(stepNumber(of: id))."
        return true
    }

    // MARK: - Editing

    func select(_ id: UUID?) {
        selectedID = id
    }

    func delete(_ id: UUID) {
        guard let removed = elements.removeStep(id)?.0 else { return }
        if let selectedID, selectedID == id || [removed].findStep(selectedID) != nil { self.selectedID = nil }
        let nested = removed.nestedCount
        statusMessage = "Deleted '\(removed.displayText)'" + (nested > 0 ? " and the steps inside it." : ".")
    }

    func deleteSelected() {
        if let selectedID { delete(selectedID) }
    }

    func duplicate(_ id: UUID) {
        guard let location = elements.location(of: id), let original = elements.findStep(id) else { return }
        var target = location
        target.index += 1
        insert(original.duplicated(), at: target)
    }

    func duplicateSelected() {
        if let selectedID { duplicate(selectedID) }
    }

    func toggleEnabled(_ id: UUID) {
        elements.updateStep(id) { $0.enabled.toggle() }
    }

    /// Replaces the step with an If / Else block that checks the same element
    /// and runs the step in its THEN branch ("do this only if it exists").
    func wrapInIf(_ id: UUID) {
        guard let location = elements.location(of: id),
              let step = elements.removeStep(id)?.0 else { return }
        var block = UIElement.makeIf(type: step.type,
                                     identifier: step.identifier,
                                     displayText: step.displayText)
        block.thenSteps = [step]
        elements.insertStep(block, at: location)
        selectedID = block.id
        statusMessage = "Wrapped '\(step.identifier)' in an If / Else block."
    }

    /// Replaces the step with a Loop block that repeats it.
    func wrapInLoop(_ id: UUID) {
        guard let location = elements.location(of: id),
              let step = elements.removeStep(id)?.0 else { return }
        var block = UIElement.makeLoop()
        block.loopSteps = [step]
        elements.insertStep(block, at: location)
        selectedID = block.id
        statusMessage = "Wrapped '\(step.displayText)' in a Loop block."
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        elements.updateStep(id) { $0.displayText = trimmed }
        statusMessage = "Renamed step \(stepNumber(of: id)) to '\(trimmed)'."
    }

    func toggleCollapsed(_ id: UUID) {
        elements.updateStep(id) { $0.isCollapsed.toggle() }
    }

    /// Minimize or expand every If / Else and Loop block.
    func setAllCollapsed(_ collapsed: Bool) {
        for step in allElements where step.isBlock {
            elements.updateStep(step.id) { $0.isCollapsed = collapsed }
        }
        statusMessage = collapsed ? "All blocks minimized." : "All blocks expanded."
    }

    func wrapSelectedInIf() {
        if let selectedID { wrapInIf(selectedID) }
    }

    /// Move earlier / later among its siblings (inspector arrows).
    func moveStep(_ id: UUID, by offset: Int) {
        guard let location = elements.location(of: id) else { return }
        let target = location.index + offset
        guard siblings(at: location).indices.contains(target) else { return }
        var tree = elements
        guard let step = tree.removeStep(id)?.0 else { return }
        var newLocation = location
        newLocation.index = target
        tree.insertStep(step, at: newLocation)
        elements = tree
    }

    // MARK: - Workflow building

    func buildWorkflow() -> Workflow {
        let bundleID = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return Workflow(name: workflowName,
                        bundleIdentifier: bundleID.isEmpty ? nil : bundleID,
                        steps: elements.enumerated().map { index, element in element.toStep(id: String(index + 1)) })
    }

    func validationIssue() -> String? {
        do {
            try WorkflowCodec.validate(buildWorkflow())
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func jsonPreview() -> String {
        do {
            return try repository.jsonString(for: buildWorkflow())
        } catch {
            return "Unable to encode workflow: \(error.localizedDescription)"
        }
    }

    func apply(_ workflow: Workflow) {
        workflowName = workflow.name
        bundleIdentifier = workflow.bundleIdentifier ?? ""
        elements = workflow.steps.map { UIElement(step: $0) }
        selectedID = nil
    }

    // MARK: - File commands

    func newWorkflow() {
        workflowName = "Untitled Workflow"
        bundleIdentifier = ""
        elements = []
        selectedID = nil
        currentFileURL = nil
        statusMessage = "New workflow. Drag elements from the palette into the sequence."
    }

    func loadLoginSample() {
        apply(SampleWorkflows.login)
        currentFileURL = nil
        statusMessage = "Loaded the Login sample (\(allElements.count) steps, with an If / Else block)."
    }

    func save() {
        if let url = currentFileURL {
            write(to: url)
        } else {
            saveAs()
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.title = "Save Workflow"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = currentFileURL?.lastPathComponent ?? "workflow.json"
        if panel.runModal() == .OK, let url = panel.url {
            write(to: url)
        }
    }

    func openWithPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Workflow"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    func open(_ url: URL) {
        do {
            let workflow = try repository.load(from: url)
            apply(workflow)
            currentFileURL = url
            statusMessage = "Opened \(url.lastPathComponent) (v\(workflow.version), \(workflow.totalStepCount) steps)."
        } catch {
            showError("Could not open workflow", error)
        }
    }

    private func write(to url: URL) {
        do {
            try repository.save(buildWorkflow(), to: url)
            currentFileURL = url
            statusMessage = "Saved \(allElements.count) steps to \(url.path)"
        } catch {
            showError("Could not save workflow", error)
        }
    }

    private func showError(_ title: String, _ error: Error) {
        statusMessage = "\(title): \(error.localizedDescription)"
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: - Helpers

    private func uniqueIdentifier(prefix: String) -> String {
        let used = Set(allElements.map(\.identifier))
        var n = 1
        while used.contains("\(prefix)_\(n)") { n += 1 }
        return "\(prefix)_\(n)"
    }
}
