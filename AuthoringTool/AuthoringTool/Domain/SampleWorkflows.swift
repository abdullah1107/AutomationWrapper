//
//  SampleWorkflows.swift
//  The login scenario used as the example in both projects.
//  Identifiers match SampleTargetApp/SampleLoginApp (the demo app under test).
//
//  Step 6 is an If / Else block: if the welcome screen appears, check it and log out;
//  otherwise check the error message.
//

import Foundation

enum SampleWorkflows {
    static let login = Workflow(
        name: "Login Flow",
        bundleIdentifier: "com.example.automation.SampleLoginApp",
        steps: [
            AutomationStep(id: "1", type: .staticText, identifier: "login_title",
                           action: .verify, condition: .equals, value: "Login", waitTime: 1, label: "Login"),
            AutomationStep(id: "2", type: .textField, identifier: "username_field",
                           action: .typeText, value: "john@example.com", waitTime: 1, label: "Enter username"),
            AutomationStep(id: "3", type: .secureTextField, identifier: "password_field",
                           action: .typeText, value: "password123", waitTime: 1, label: "Enter password"),
            AutomationStep(id: "4", type: .toggleSwitch, identifier: "remember_switch",
                           action: .toggle, waitTime: 1, label: "Remember me"),
            AutomationStep(id: "5", type: .button, identifier: "login_button",
                           action: .tap, waitTime: 2, label: "Login"),
            AutomationStep(
                id: "6", kind: .ifElse, type: .staticText, identifier: "welcome_label",
                condition: .exists, timeout: 5, waitTime: 0,
                thenSteps: [
                    AutomationStep(id: "6.T1", type: .staticText, identifier: "remember_status_label",
                                   action: .verify, condition: .equals, value: "Remember me: On", waitTime: 0, label: "Remember me: On"),
                    AutomationStep(id: "6.T2", type: .button, identifier: "logout_button",
                                   action: .tap, waitTime: 1, label: "Log out")
                ],
                elseSteps: [
                    AutomationStep(id: "6.E1", type: .staticText, identifier: "error_label",
                                   action: .verify, condition: .contains, value: "Invalid", waitTime: 0, label: "Invalid username or password")
                ], label: "Welcome!")
        ]
    )
}
