//
//  ElementView.swift
//  The card shown for one step in the design area: collapse chevron (blocks),
//  step number, the step's name (double-click to rename) and what the step does.
//

import SwiftUI

struct ElementView: View {
    let element: UIElement
    let stepNumber: String
    /// When true the name is an editable text field.
    var isRenaming: Binding<Bool> = .constant(false)
    var onRename: (String) -> Void = { _ in }
    var onToggleCollapse: () -> Void = {}

    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if element.isBlock {
                Button(action: onToggleCollapse) {
                    Image(systemName: element.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(accent)
                .help(element.isCollapsed ? "Expand" : "Minimize")
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 16)
            }

            Text(stepNumber)
                .font(.caption.monospacedDigit().bold())
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 22, minHeight: 22)
                .background(Capsule().fill(element.isBlock ? accent : Color.orange))

            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(element.isBlock ? accent : .accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let tag = blockTag {
                        Text(tag)
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(accent.opacity(0.2)))
                            .foregroundColor(accent)
                    }
                    nameView
                }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if element.isBlock && element.isCollapsed {
                Text("\(element.nestedCount) step\(element.nestedCount == 1 ? "" : "s") hidden")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundStyle(.secondary)
            }
            if !element.enabled {
                Text("disabled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !element.isBlock && element.waitTime > 0 {
                Label("\(element.waitTime.formatted())s", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Name / rename

    @ViewBuilder
    private var nameView: some View {
        if isRenaming.wrappedValue {
            TextField("Step name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 160, maxWidth: 280)
                .focused($nameFocused)
                .onAppear {
                    draftName = element.displayText
                    nameFocused = true
                }
                .onSubmit(commitRename)
                .onExitCommand { isRenaming.wrappedValue = false }
                .onChange(of: nameFocused) { focused in
                    if !focused && isRenaming.wrappedValue { commitRename() }
                }
        } else {
            Text(element.displayText.isEmpty ? "Untitled step" : element.displayText)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .help("Double-click the step to rename it")
        }
    }

    private func commitRename() {
        onRename(draftName)
        isRenaming.wrappedValue = false
    }

    // MARK: Text

    private var accent: Color {
        element.isLoop ? .teal : .purple
    }

    private var icon: String {
        if element.isIf { return "arrow.triangle.branch" }
        if element.isLoop { return "repeat" }
        return element.type.systemImage
    }

    private var blockTag: String? {
        if element.isIf { return "IF" }
        if element.isLoop { return "LOOP" }
        return nil
    }

    /// What the step does, e.g. Type Text "john@example.com" · Text Field · username_field.
    private var summary: String {
        if element.isLoop {
            return "Repeat \(element.repeatCount)× · \(element.loopSteps.count) step(s) inside"
        }
        if element.isIf {
            var text = "Verify \(element.identifier) · \(element.condition.displayName)"
            if element.condition.needsValue { text += " \"\(shownValue)\"" }
            return text
        }
        var text = element.action.displayName
        if element.action == .verify {
            text += " · \(element.condition.displayName)"
            if element.condition.needsValue { text += " \"\(shownValue)\"" }
        } else if element.usesValue && !element.value.isEmpty {
            text += " \"\(shownValue)\""
        }
        return text + " · \(element.type.displayName) · \(element.identifier)"
    }

    private var shownValue: String {
        if element.type == .secureTextField { return String(repeating: "•", count: element.value.count) }
        return element.value
    }
}
