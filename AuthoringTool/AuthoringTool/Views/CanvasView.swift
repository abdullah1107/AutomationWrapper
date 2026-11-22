//
//  CanvasView.swift
//  Design area: no screen mock-up, just the execution flow. Steps are cards in a
//  vertical list and run top to bottom. Everything is drag & drop:
//    • drag palette items onto a card (inserts before it), onto a THEN / ELSE header,
//      or onto the slot at the end
//    • drag a card to reorder it, or into / out of an If / Else block
//

import SwiftUI

struct CanvasView: View {
    @EnvironmentObject private var vm: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Design Area – Execution Sequence")
                    .font(.headline)
                Spacer()
                Text("\(vm.allElements.count) steps · run top to bottom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button { vm.setAllCollapsed(true) } label: { Image(systemName: "rectangle.compress.vertical") }
                    .buttonStyle(.borderless)
                    .help("Minimize all If / Else and Loop blocks")
                Button { vm.setAllCollapsed(false) } label: { Image(systemName: "rectangle.expand.vertical") }
                    .buttonStyle(.borderless)
                    .help("Expand all blocks")
            }
            .padding(12)

            ScrollView {
                VStack(spacing: 0) {
                    FlowMarker(title: "START", systemImage: "play.fill", color: .green)
                    FlowConnector()

                    VStack(alignment: .leading, spacing: 0) {
                        StepListView(steps: vm.elements, parentID: nil, branch: .thenBranch, showsConnectors: true)
                        if !vm.elements.isEmpty { FlowConnector() }
                        DropSlotView(title: vm.elements.isEmpty
                                        ? "Drag elements, an If / Else or a Loop block from the palette here"
                                        : "Drop here to add at the end",
                                     location: .root(vm.elements.count),
                                     height: vm.elements.isEmpty ? 90 : 40)
                    }

                    FlowConnector()
                    FlowMarker(title: "END", systemImage: "stop.fill", color: .red)
                }
                .frame(maxWidth: 620)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { vm.select(nil) }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct FlowMarker: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(color))
    }
}

/// Small down arrow between consecutive steps.
struct FlowConnector: View {
    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 18)
    }
}
