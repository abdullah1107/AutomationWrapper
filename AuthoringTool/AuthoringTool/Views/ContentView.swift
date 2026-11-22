//
//  ContentView.swift
//  Palette | Design area (execution sequence, drag & drop) | Inspector
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: EditorViewModel
    @State private var showingJSON = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                PaletteView()
                    .frame(width: 240)
                Divider()
                CanvasView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                InspectorView()
                    .frame(width: 360)
            }
            Divider()
            statusBar
        }
        .navigationTitle(vm.currentFileURL?.lastPathComponent ?? "Authoring Tool")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                TextField("Workflow name", text: $vm.workflowName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .help("Workflow name (saved as \"name\" in the JSON)")
            }
            ToolbarItem(placement: .navigation) {
                TextField("App bundle identifier", text: $vm.bundleIdentifier)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                    .help("Bundle identifier of the iOS app the Execution Tool will drive")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { vm.newWorkflow() } label: { Label("New", systemImage: "doc") }
                    .help("New empty workflow")
                Button { vm.loadLoginSample() } label: { Label("Login Sample", systemImage: "person.badge.key") }
                    .help("Load the Login sample")
                Button { vm.addIfBlock() } label: { Label("If / Else", systemImage: "arrow.triangle.branch") }
                    .help("Add an If / Else block at the end")
                Button { vm.addLoopBlock() } label: { Label("Loop", systemImage: "repeat") }
                    .help("Add a Loop (repeat N times) block at the end")
                Button { vm.openWithPanel() } label: { Label("Open", systemImage: "folder") }
                    .help("Open / import a workflow.json")
                Button { showingJSON = true } label: { Label("Preview JSON", systemImage: "curlybraces") }
                    .help("Preview the generated JSON")
                Button { vm.save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    .help("Save workflow.json")
            }
        }
        .sheet(isPresented: $showingJSON) {
            JSONPreviewView(json: vm.jsonPreview(), issue: vm.validationIssue())
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let issue = vm.validationIssue() {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(issue).foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text(vm.statusMessage)
            }
            Spacer()
            Text("\(vm.allElements.count) steps · schema v\(Workflow.currentVersion)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
