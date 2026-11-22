//
//  InspectorView.swift
//  Properties inspector for the selected step (action step or If / Else block).
//

import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var vm: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Properties Inspector")
                .font(.headline)
                .padding(12)

            if let id = vm.selectedID, vm.elements.findStep(id) != nil {
                ElementInspector(element: vm.binding(for: id))
                    .id(id)
            } else {
                Text("Select a step in the sequence to edit its properties.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                Spacer()
            }
        }
    }
}

private struct ElementInspector: View {
    @Binding var element: UIElement
    @EnvironmentObject private var vm: EditorViewModel

    var body: some View {
        Form {
            Section("Step") {
                TextField("Step Name", text: $element.displayText)
                    .help("Name shown in the design area (saved as \"label\"). You can also double-click a step to rename it.")
                if element.isBlock {
                    Toggle("Minimized", isOn: $element.isCollapsed)
                }
            }

            if element.isLoop {
                loopSection
            } else {
                Section(element.isIf ? "If – verify this element" : "Element") {
                    Picker("Element Type", selection: $element.type) {
                        ForEach(ElementCategory.exclusive) { category in
                            Section(category.rawValue) {
                                ForEach(category.types) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                        }
                    }
                    TextField("Identifier", text: $element.identifier)
                        .help("Accessibility identifier of the element in the app under test")
                }

                if element.isIf {
                    ifSection
                } else {
                    actionSection
                }
            }

            Section {
                HStack {
                    Text("Step \(vm.stepNumber(of: element.id))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { vm.moveStep(element.id, by: -1) } label: { Image(systemName: "arrow.up") }
                        .help("Execute earlier")
                    Button { vm.moveStep(element.id, by: 1) } label: { Image(systemName: "arrow.down") }
                        .help("Execute later")
                    Button { vm.duplicate(element.id) } label: { Image(systemName: "plus.square.on.square") }
                        .help("Duplicate")
                    Button { vm.wrapInIf(element.id) } label: { Image(systemName: "arrow.triangle.branch") }
                        .help("Wrap in If / Else")
                    Button { vm.wrapInLoop(element.id) } label: { Image(systemName: "repeat") }
                        .help("Wrap in Loop")
                    Button(role: .destructive) { vm.delete(element.id) } label: { Image(systemName: "trash") }
                        .help(element.isBlock ? "Delete block and the steps inside it" : "Delete step")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Sections

    private var loopSection: some View {
        Section("Loop") {
            Stepper(value: $element.repeatCount, in: 1...10_000) {
                HStack {
                    Text("Repeat")
                    TextField("", value: $element.repeatCount, format: .number)
                        .frame(width: 60)
                    Text("times")
                }
            }
            LabeledContent("DO", value: "\(element.loopSteps.count) step(s)")
            TextField("Wait After (sec)", value: $element.waitTime, format: .number)
                .help("Seconds to pause after the whole loop finishes")
            Text("Drag steps into the DO section of this block in the design area.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Enabled", isOn: $element.enabled)
        }
    }

    private var ifSection: some View {
        Section("Verify") {
            conditionPicker
            if element.condition.needsValue {
                TextField("Expected Text", text: $element.value, prompt: Text(expectedPrompt))
            }
            TextField("Timeout (sec)", value: $element.timeout, format: .number)
                .help("How long to wait for the verify to become true before taking ELSE. 0 = default (3 s).")
            LabeledContent("THEN", value: "\(element.thenSteps.count) step(s)")
            LabeledContent("ELSE", value: "\(element.elseSteps.count) step(s)")
            Text("Drag steps into the THEN / ELSE sections of this block in the Execution Sequence.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Enabled", isOn: $element.enabled)
        }
    }

    private var actionSection: some View {
        Section("Action") {
            Picker("Action Type", selection: $element.action) {
                ForEach(element.type.supportedActions) { action in
                    Text(action.displayName).tag(action)
                }
            }
            if element.action == .verify {
                conditionPicker
            }
            if element.usesValue {
                TextField(valueLabel, text: $element.value, prompt: Text(valuePrompt))
            }
            TextField("Timeout (sec)", value: $element.timeout, format: .number)
                .help("How long to wait for the element. 0 = default (10 s).")
            TextField("Wait After (sec)", value: $element.waitTime, format: .number)
                .help("Seconds to pause after this step succeeds")
            Toggle("Enabled", isOn: $element.enabled)
        }
    }

    private var conditionPicker: some View {
        Picker("Condition", selection: $element.condition) {
            ForEach(ConditionType.allCases) { condition in
                Text(condition.displayName).tag(condition)
            }
        }
    }

    // MARK: Labels

    private var valueLabel: String {
        switch element.action {
        case .typeText:          return "Text to Type"
        case .longPress:         return "Duration (sec)"
        case .adjustSlider:      return "Slider Position (0–1)"
        case .selectPickerValue: return "Picker Value"
        case .verify:            return element.condition == .contains ? "Text Contains" : "Expected Text"
        default:                 return "Value"
        }
    }

    private var valuePrompt: String {
        switch element.action {
        case .typeText:          return "e.g. john@example.com"
        case .longPress:         return "Empty = 1"
        case .adjustSlider:      return "e.g. 0.5"
        case .selectPickerValue: return "e.g. March"
        default:                 return expectedPrompt
        }
    }

    private var expectedPrompt: String { "e.g. Welcome!" }
}
