//
//  PaletteView.swift
//  Component palette – the If / Else logic block plus every XCUIElement type,
//  grouped and searchable. Each item can be dragged into the Execution
//  Sequence (including into an If / Else branch).
//

import SwiftUI

struct PaletteView: View {
    @EnvironmentObject private var vm: EditorViewModel
    @State private var search = ""
    @State private var collapsed: Set<ElementCategory> = Set(ElementCategory.allCases.filter { $0 != .common })

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Component Palette")
                .font(.headline)
            Text("Drag into the sequence (or into THEN / ELSE). Double-click to add at the end.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Search \(ElementType.allCases.count) element types", text: $search)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if showsLogic {
                        Text("Logic")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        PaletteBlockView(item: .ifBlock, title: "If / Else", systemImage: "arrow.triangle.branch",
                                         tint: .purple,
                                         help: "Verify an element (exists, text equals, enabled…). THEN steps run when it is true, ELSE steps when it is false.") {
                            vm.addIfBlock()
                        }
                        PaletteBlockView(item: .loopBlock, title: "Loop (repeat N times)", systemImage: "repeat",
                                         tint: .teal,
                                         help: "Repeat the steps inside it a number of times (for loop).") {
                            vm.addLoopBlock()
                        }
                        Divider().padding(.vertical, 4)
                    }

                    ForEach(visibleCategories) { category in
                        DisclosureGroup(isExpanded: expansion(for: category)) {
                            VStack(spacing: 4) {
                                ForEach(types(in: category)) { type in
                                    PaletteItemView(type: type)
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            HStack {
                                Text(category.rawValue).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(types(in: category).count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if visibleCategories.isEmpty && !showsLogic {
                        Text("No element type matches \"\(search)\".")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(12)
    }

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }

    private var showsLogic: Bool {
        guard isSearching else { return true }
        let query = search.lowercased()
        return ["if", "else", "condition", "logic", "loop", "repeat", "for"].contains { $0.contains(query) || query.contains($0) }
    }

    /// While searching, Common is hidden so each match is listed once.
    private var visibleCategories: [ElementCategory] {
        let categories = isSearching ? ElementCategory.exclusive : ElementCategory.allCases
        return categories.filter { !types(in: $0).isEmpty }
    }

    private func types(in category: ElementCategory) -> [ElementType] {
        category.types.filter { $0.matches(search: search) }
    }

    private func expansion(for category: ElementCategory) -> Binding<Bool> {
        Binding(
            get: { isSearching || !collapsed.contains(category) },
            set: { isOpen in
                if isOpen { collapsed.remove(category) } else { collapsed.insert(category) }
            }
        )
    }
}

private struct PaletteItemView: View {
    let type: ElementType
    @EnvironmentObject private var vm: EditorViewModel

    var body: some View {
        PaletteRow(systemImage: type.systemImage, title: type.displayName, tint: .accentColor)
            .draggable(DragItem.element(type).payload) {
                PaletteRow(systemImage: type.systemImage, title: type.displayName, tint: .accentColor)
                    .frame(width: 190)
            }
            .onTapGesture(count: 2) {
                vm.addElement(type)
            }
            .help("\(type.displayName) (XCUIElement.ElementType.\(type.rawValue)) – default action: \(type.defaultAction.displayName)")
    }
}

private struct PaletteBlockView: View {
    let item: DragItem
    let title: String
    let systemImage: String
    let tint: Color
    let help: String
    let add: () -> Void

    var body: some View {
        PaletteRow(systemImage: systemImage, title: title, tint: tint)
            .draggable(item.payload) {
                PaletteRow(systemImage: systemImage, title: title, tint: tint)
                    .frame(width: 190)
            }
            .onTapGesture(count: 2, perform: add)
            .help(help)
    }
}

private struct PaletteRow: View {
    let systemImage: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundColor(tint)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
