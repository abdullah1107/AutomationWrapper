//
//  AuthoringToolApp.swift
//  AuthoringTool – drag & drop editor that produces workflow.json
//

import SwiftUI

@main
struct AuthoringToolApp: App {
    @StateObject private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup("Automation Authoring Tool") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1150, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Workflow") { viewModel.newWorkflow() }
                    .keyboardShortcut("n")
                Button("Open Workflow…") { viewModel.openWithPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { viewModel.save() }
                    .keyboardShortcut("s")
                Button("Save As…") { viewModel.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Workflow") {
                Button("Load Login Sample") { viewModel.loadLoginSample() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Divider()
                Button("Add If / Else Block") { viewModel.addIfBlock() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Add Loop Block") { viewModel.addLoopBlock() }
                    .keyboardShortcut("l", modifiers: [.command, .option])
                Button("Wrap Selected in If / Else") { viewModel.wrapSelectedInIf() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Divider()
                Button("Minimize All Blocks") { viewModel.setAllCollapsed(true) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                Button("Expand All Blocks") { viewModel.setAllCollapsed(false) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Button("Duplicate Selected Step") { viewModel.duplicateSelected() }
                    .keyboardShortcut("d")
                Divider()
                Button("Delete Selected Step") { viewModel.deleteSelected() }
                    .keyboardShortcut(.delete, modifiers: [.command])
            }
        }
    }
}
