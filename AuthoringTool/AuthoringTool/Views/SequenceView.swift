//
//  SequenceView.swift
//  Building blocks of the drag & drop step tree shown in the design area
//  (CanvasView): step rows (rename, minimize / expand), If / Else and Loop blocks,
//  branch headers and drop slots.
//

import SwiftUI

struct StepListView: View {
    let steps: [UIElement]
    let parentID: UUID?
    let branch: Branch
    /// Draw a down arrow between steps (root level of the flow).
    var showsConnectors = false

    var body: some View {
        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
            if showsConnectors && index > 0 {
                FlowConnector()
            }
            StepRowView(step: step,
                        location: StepLocation(parentID: parentID, branch: branch, index: index))
                .padding(.bottom, showsConnectors ? 0 : 4)
        }
    }
}

private struct StepRowView: View {
    let step: UIElement
    let location: StepLocation

    @EnvironmentObject private var vm: EditorViewModel
    @State private var isTargeted = false
    @State private var isRenaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            card
            if step.isBlock && !step.isCollapsed {
                if step.isIf { ifBlock }
                if step.isLoop { loopBlock }
            }
        }
        .padding(step.isBlock ? 6 : 0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(step.isBlock ? accent.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(step.isBlock ? accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    private var accent: Color { step.isLoop ? .teal : .purple }

    // MARK: Card

    private var isSelected: Bool { vm.selectedID == step.id }

    private var card: some View {
        ElementView(element: step,
                    stepNumber: vm.stepNumber(of: step.id),
                    isRenaming: $isRenaming,
                    onRename: { vm.rename(step.id, to: $0) },
                    onToggleCollapse: { vm.toggleCollapsed(step.id) })
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .top) {
                InsertionLine(visible: isTargeted).offset(y: -4)
            }
            .opacity(step.enabled ? 1 : 0.5)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                vm.select(step.id)
                isRenaming = true
            }
            .onTapGesture { vm.select(step.id) }
            .draggable(DragItem.step(step.id).payload) {
                ElementView(element: step, stepNumber: vm.stepNumber(of: step.id))
                    .padding(8)
                    .frame(width: 380, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
            }
            .dropDestination(for: String.self) { items, _ in
                vm.handleDrop(items, at: location)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .contextMenu { contextMenuItems }
            .help(step.isBlock
                  ? "Drag to move the whole block · double-click to rename · chevron to minimize / expand"
                  : "Drag to reorder or into a block · double-click to rename")
    }

    // MARK: If / Else block

    private var ifBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            ConditionSlotView(blockID: step.id)
            branchSection(.thenBranch, subtitle: "runs when the verify is true", color: .green)
            branchSection(.elseBranch, subtitle: "runs when the verify is false", color: .orange)
            Text("END IF")
                .font(.caption2.bold())
                .foregroundColor(Color.purple.opacity(0.8))
                .padding(.leading, 4)
        }
        .padding(.leading, 12)
    }

    // MARK: Loop block

    private var loopBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            RepeatSlotView(blockID: step.id)
            branchSection(.loopBody, subtitle: "runs \(step.repeatCount) time\(step.repeatCount == 1 ? "" : "s"), top to bottom",
                          color: .teal)
            Text("END LOOP")
                .font(.caption2.bold())
                .foregroundColor(Color.teal.opacity(0.9))
                .padding(.leading, 4)
        }
        .padding(.leading, 12)
    }

    @ViewBuilder
    private func branchSection(_ branch: Branch, subtitle: String, color: Color) -> some View {
        let children = step.children(branch)
        let endOfBranch = StepLocation(parentID: step.id, branch: branch, index: children.count)

        BranchHeaderView(title: branch.title, subtitle: subtitle, color: color, location: endOfBranch)
        VStack(alignment: .leading, spacing: 0) {
            StepListView(steps: children, parentID: step.id, branch: branch)
            if children.isEmpty {
                DropSlotView(title: "Drop steps here", location: endOfBranch)
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 2)
                .padding(.leading, 4)
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Rename…") {
            vm.select(step.id)
            isRenaming = true
        }
        if step.isBlock {
            Button(step.isCollapsed ? "Expand" : "Minimize") { vm.toggleCollapsed(step.id) }
        }
        Divider()
        Button("Duplicate") { vm.duplicate(step.id) }
        Button("Wrap in If / Else") { vm.wrapInIf(step.id) }
        Button("Wrap in Loop") { vm.wrapInLoop(step.id) }
        Button(step.enabled ? "Disable" : "Enable") { vm.toggleEnabled(step.id) }
        Divider()
        Button("Move Up") { vm.moveStep(step.id, by: -1) }
        Button("Move Down") { vm.moveStep(step.id, by: 1) }
        Divider()
        Button("Delete", role: .destructive) { vm.delete(step.id) }
    }
}

// MARK: - Loop count (REPEAT slot)

private struct RepeatSlotView: View {
    let blockID: UUID

    @EnvironmentObject private var vm: EditorViewModel

    var body: some View {
        let block = vm.binding(for: blockID)

        HStack(spacing: 8) {
            Text("REPEAT")
                .font(.caption.bold())
                .foregroundColor(.teal)
            TextField("", value: block.repeatCount, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            Stepper("", value: block.repeatCount, in: 1...10_000)
                .labelsHidden()
            Text("times")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.teal.opacity(0.08))
        )
    }
}

// MARK: - If condition (VERIFY slot)

/// The verify an If block checks. Drop a palette element or an existing step here to
/// choose the element; pick the check and expected text right here.
private struct ConditionSlotView: View {
    let blockID: UUID

    @EnvironmentObject private var vm: EditorViewModel
    @State private var isTargeted = false

    var body: some View {
        let block = vm.binding(for: blockID)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("VERIFY")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                Text("drop an element here to check it")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: block.wrappedValue.type.systemImage)
                    .foregroundColor(.purple)
                    .frame(width: 18)
                TextField("identifier", text: block.identifier)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)
                    .help("Accessibility identifier of the \(block.wrappedValue.type.displayName) to verify")
                Picker("", selection: block.condition) {
                    ForEach(ConditionType.allCases) { condition in
                        Text(condition.displayName).tag(condition)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
                if block.wrappedValue.condition.needsValue {
                    TextField("expected text", text: block.value)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 100)
                }
            }
            Text(block.wrappedValue.type.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 26)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isTargeted ? Color.purple.opacity(0.25) : Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTargeted ? Color.purple : Color.purple.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .dropDestination(for: String.self) { items, _ in
            vm.handleConditionDrop(items, on: blockID)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

// MARK: - Drop targets

private struct BranchHeaderView: View {
    let title: String
    let subtitle: String
    let color: Color
    let location: StepLocation

    @EnvironmentObject private var vm: EditorViewModel
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isTargeted ? color.opacity(0.3) : color.opacity(0.1))
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            vm.handleDrop(items, at: location)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .help("Drop here to add at the end of \(title)")
    }
}

struct DropSlotView: View {
    let title: String
    let location: StepLocation
    var height: CGFloat = 32

    @EnvironmentObject private var vm: EditorViewModel
    @State private var isTargeted = false

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
                vm.handleDrop(items, at: location)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}

private struct InsertionLine: View {
    let visible: Bool

    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(height: 3)
            .opacity(visible ? 1 : 0)
    }
}
