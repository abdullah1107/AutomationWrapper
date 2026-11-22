//
//  SampleLoginApp.swift
//  The iOS app under test. Accessibility identifiers match the Login sample workflow.
//

import SwiftUI

@main
struct SampleLoginApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}

enum AuthService {
    /// Demo credentials used by the sample workflow.
    static let validUsername = "john@example.com"
    static let validPassword = "password123"

    static func validate(username: String, password: String) -> Bool {
        username.trimmingCharacters(in: .whitespaces).lowercased() == validUsername && password == validPassword
    }
}
