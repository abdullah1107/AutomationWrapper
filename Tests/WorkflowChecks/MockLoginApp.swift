// Test double: behaves like SampleTargetApp/SampleLoginApp so the real engine can run workflows.
import Foundation

final class MockLoginApp: UIAutomationDriver {
    enum Screen { case login, home }

    var screen = Screen.login
    var username = ""
    var password = ""
    var rememberMe = false
    var errorMessage: String?
    var counters: [String: Int] = [:]          // identifier -> number of taps/swipes
    var actions: [String] = []

    let validUser = "john@example.com"
    let validPassword = "password123"

    private struct Node {
        let type: ElementType
        let text: String
        var enabled = true
        var selected = false
    }

    private var nodes: [String: Node] {
        switch screen {
        case .login:
            var n: [String: Node] = [
                "login_title": Node(type: .staticText, text: "Login"),
                "username_field": Node(type: .textField, text: username.isEmpty ? "Enter username" : username),
                "password_field": Node(type: .secureTextField, text: String(repeating: "•", count: password.count)),
                "remember_switch": Node(type: .toggleSwitch, text: rememberMe ? "1" : "0", selected: rememberMe),
                "login_button": Node(type: .button, text: "Login"),
                "items_table": Node(type: .table, text: "")
            ]
            if let errorMessage { n["error_label"] = Node(type: .staticText, text: errorMessage) }
            return n
        case .home:
            return [
                "success_image": Node(type: .image, text: "checkmark"),
                "welcome_label": Node(type: .staticText, text: "Welcome!"),
                "signed_in_label": Node(type: .staticText, text: "Signed in as \(username)"),
                "remember_status_label": Node(type: .staticText, text: rememberMe ? "Remember me: On" : "Remember me: Off"),
                "logout_button": Node(type: .button, text: "Log out")
            ]
        }
    }

    private func node(_ locator: ElementLocator) throws -> Node {
        guard let node = nodes[locator.identifier] else {
            throw DriverError.elementNotFound(locator, timeout: 0)
        }
        return node
    }

    func snapshot(_ locator: ElementLocator) -> ElementSnapshot? {
        guard let node = nodes[locator.identifier] else { return nil }
        return ElementSnapshot(isEnabled: node.enabled, isSelected: node.selected, isHittable: true, text: node.text)
    }

    func exists(_ locator: ElementLocator, timeout: TimeInterval) -> Bool { nodes[locator.identifier] != nil }

    func perform(_ gesture: Gesture, on locator: ElementLocator, timeout: TimeInterval) throws {
        _ = try node(locator)
        actions.append("\(gesture) \(locator.identifier)")
        counters[locator.identifier, default: 0] += 1
        guard case .tap = gesture else { return }
        switch locator.identifier {
        case "login_button":
            if username == validUser && password == validPassword {
                screen = .home; errorMessage = nil
            } else {
                errorMessage = "Invalid username or password"
            }
        case "logout_button":
            screen = .login; password = ""
        default: break
        }
    }

    func typeText(_ text: String, into locator: ElementLocator, timeout: TimeInterval) throws {
        _ = try node(locator)
        actions.append("type \(locator.identifier)")
        if locator.identifier == "username_field" { username = text }
        if locator.identifier == "password_field" { password = text }
    }

    func clearText(_ locator: ElementLocator, timeout: TimeInterval) throws {
        _ = try node(locator)
        if locator.identifier == "username_field" { username = "" }
        if locator.identifier == "password_field" { password = "" }
    }

    func toggle(_ locator: ElementLocator, timeout: TimeInterval) throws {
        _ = try node(locator)
        actions.append("toggle \(locator.identifier)")
        if locator.identifier == "remember_switch" { rememberMe.toggle() }
    }

    func adjustSlider(_ locator: ElementLocator, to position: Double, timeout: TimeInterval) throws { _ = try node(locator) }
    func selectPickerValue(_ value: String, in locator: ElementLocator, timeout: TimeInterval) throws { _ = try node(locator) }
    func getText(_ locator: ElementLocator, timeout: TimeInterval) throws -> String { try node(locator).text }
    /// Keeps tests fast: real waits are capped.
    func wait(seconds: TimeInterval) { Thread.sleep(forTimeInterval: min(seconds, 0.01)) }
}
