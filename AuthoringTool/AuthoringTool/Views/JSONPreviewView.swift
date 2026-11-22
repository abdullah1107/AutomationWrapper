//
//  JSONPreviewView.swift
//  Shows the JSON that will be written to workflow.json.
//

import SwiftUI
import AppKit

struct JSONPreviewView: View {
    let json: String
    let issue: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("workflow.json").font(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                }
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            if let issue {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }

            ScrollView {
                Text(json)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .frame(width: 560, height: 620)
    }
}
