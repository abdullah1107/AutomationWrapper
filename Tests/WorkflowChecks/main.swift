// WorkflowChecks – reads the real workflow JSON files with the Execution Tool's loader, runs them with the
// real WorkflowEngine against MockLoginApp (a stand-in for SampleLoginApp), and checks the Authoring Tool model.
// Run it with ../../verify_all.sh (or: swiftc … && ./workflow_checks <Wrapper+Automation folder>).
import Foundation

var failures = 0
var checks = 0
func check(_ ok: Bool, _ what: String, file: String = #file, line: Int = #line) {
    checks += 1
    if ok { print("  ✅ \(what)") } else { failures += 1; print("  ❌ \(what)  (main.swift:\(line))") }
}
func section(_ title: String) { print("\n== \(title)") }

let root = URL(fileURLWithPath: CommandLine.arguments[1])          // Wrapper+Automation folder (staged)
let files = [
    "workflow.json",
    "workflow_if_else_example.json",
    "ExecutionTool/ExecutionTool/Workflows/login_workflow.json",
]

/// Fast resolver so failure cases don't wait 10 s per retry.
func fastEngine(_ app: MockLoginApp, log: Bool = true) -> WorkflowEngine {
    var resolver = ActionResolver.standard()
    resolver.elementTimeout = 0.3
    resolver.retryTimeout = 0.1
    resolver.maxRetries = 1
    let engine = WorkflowEngine(driver: app, resolver: resolver)
    engine.conditionTimeout = 0.3
    engine.log = log ? { print("     [WORKFLOW] \($0)") } : { _ in }
    return engine
}

func shortenTimeouts(_ steps: [AutomationStep]) -> [AutomationStep] {
    steps.map { step in
        var s = step
        if s.timeout != nil { s.timeout = 0.3 }
        s.thenSteps = s.thenSteps.map(shortenTimeouts)
        s.elseSteps = s.elseSteps.map(shortenTimeouts)
        s.loopSteps = s.loopSteps.map(shortenTimeouts)
        return s
    }
}

// MARK: 1. Read every JSON file with the Execution Tool's loader

section("1. Read JSON files with WorkflowLoader (the Execution Tool's JSON decoder)")
var loaded: [String: Workflow] = [:]
for file in files {
    do {
        let wf = try WorkflowLoader().load(from: root.appendingPathComponent(file))
        loaded[file] = wf
        check(true, "\(file): v\(wf.version), '\(wf.name)', \(wf.steps.count) top-level / \(wf.totalStepCount) total steps")
    } catch {
        check(false, "\(file): \(error)")
    }
}

// Which app is driven (same logic as WorkflowRunner)
if let wf = loaded["workflow_if_else_example.json"] {
    let id = try? WorkflowSource.targetBundleIdentifier(for: wf, environment: [:])
    check(id == "com.example.automation.SampleLoginApp", "bundle id from JSON → \(id ?? "nil")")
    let overridden = try? WorkflowSource.targetBundleIdentifier(for: wf, environment: ["TARGET_BUNDLE_ID": "com.me.App"])
    check(overridden == "com.me.App", "TARGET_BUNDLE_ID overrides the JSON")
}
if let wf = loaded["workflow.json"] {
    do { _ = try WorkflowSource.targetBundleIdentifier(for: wf, environment: [:]); check(false, "workflow.json has no bundle id → should need --bundle-id") }
    catch { check(true, "workflow.json has no bundleIdentifier → needs --bundle-id: \(error.localizedDescription)") }
}
do {
    let url = try WorkflowSource.resolveURL(in: .main, environment: ["WORKFLOW_PATH": root.appendingPathComponent("workflow_if_else_example.json").path])
    check(url.lastPathComponent == "workflow_if_else_example.json", "WORKFLOW_PATH picks the file to run")
} catch { check(false, "WORKFLOW_PATH: \(error)") }

// MARK: 2. Run the flat v1 workflows

section("2. Run the version-1 login workflows (flat list)")
for file in ["workflow.json", "ExecutionTool/ExecutionTool/Workflows/login_workflow.json"] {
    guard let wf = loaded[file] else { continue }
    let app = MockLoginApp()
    let report = fastEngine(app, log: false).run(wf)
    check(report.passed, "\(file) PASSED (\(report.results.filter { $0.status == .passed }.count) passed)")
    if !report.passed { print(report.summary) }
}

// MARK: 3. If / Else

section("3. If / Else example – correct password → THEN branch")
if let wf = loaded["workflow_if_else_example.json"] {
    let app = MockLoginApp()
    let report = fastEngine(app).run(wf)
    check(report.passed, "workflow passed")
    let ifResult = report.results.first { $0.step.id == "6" }
    check(ifResult?.message == "condition true → then", "if step 6 took THEN (\(ifResult?.message ?? "-"))")
    check(report.results.contains { $0.step.id == "6.T2" && $0.status == .passed }, "6.T2 tapped logout_button")
    check(!report.results.contains { $0.step.id == "6.E1" }, "ELSE step 6.E1 did not run")
    check(app.screen == .login, "app is back on the login screen after logout")

    section("3b. If / Else example – wrong password → ELSE branch")
    var wrong = wf
    wrong.steps[2].value = "wrong-password"
    wrong.steps = shortenTimeouts(wrong.steps)
    let app2 = MockLoginApp()
    let report2 = fastEngine(app2).run(wrong)
    check(report2.passed, "workflow passed")
    check(report2.results.first { $0.step.id == "6" }?.message == "condition false → else", "if step 6 took ELSE")
    check(report2.results.contains { $0.step.id == "6.E1" && $0.status == .passed }, "6.E1 verified error_label contains \"Invalid\"")
    check(!report2.results.contains { $0.step.id.hasPrefix("6.T") }, "THEN steps did not run")
}

// MARK: 4. Loop + nested if inside loop, read from JSON text

section("4. Loop block read from JSON (repeat 3×, with an if inside)")
let loopJSON = """
{
  "version": 2, "name": "Loop test", "bundleIdentifier": "x",
  "steps": [
    { "id": "1", "kind": "loop", "label": "Scroll 3 times", "repeatCount": 3, "collapsed": true,
      "steps": [
        { "id": "1.L1", "type": "table", "identifier": "items_table", "action": "swipeUp" },
        { "id": "1.L2", "kind": "if", "type": "staticText", "identifier": "error_label", "condition": "exists", "timeout": 0.2,
          "then": [ { "id": "1.L2.T1", "type": "button", "identifier": "login_button", "action": "tap" } ],
          "else": [ { "id": "1.L2.E1", "type": "button", "identifier": "login_button", "action": "doubleTap" } ] }
      ] },
    { "id": "2", "type": "staticText", "identifier": "login_title", "action": "verify", "condition": "contains", "value": "Log" }
  ]
}
"""
do {
    let wf = try WorkflowCodec.decode(Data(loopJSON.utf8))
    check(wf.steps[0].isLoop && wf.steps[0].resolvedRepeatCount == 3, "loop decoded without type / identifier")
    check(wf.totalStepCount == 6, "totalStepCount counts nested steps (\(wf.totalStepCount))")
    let app = MockLoginApp()
    let report = fastEngine(app).run(wf)
    check(report.passed, "loop workflow passed")
    check(app.counters["items_table"] == 3, "body ran 3 times (swipes: \(app.counters["items_table"] ?? 0))")
    check(report.results.first { $0.step.id == "1" }?.message == "3/3 iterations completed", "loop result: 3/3 iterations")
    check(app.actions.filter { $0.hasPrefix("doubleTap") }.count == 3, "inner if took ELSE in every iteration")

    let reencoded = try WorkflowCodec.encode(wf)
    let text = String(decoding: reencoded, as: UTF8.self)
    let loopObject = try JSONSerialization.jsonObject(with: reencoded) as! [String: Any]
    let firstStep = (loopObject["steps"] as! [[String: Any]])[0]
    check(firstStep["type"] == nil && firstStep["identifier"] == nil, "encoded loop has no type / identifier")
    check(text.contains("\"repeatCount\" : 3") && text.contains("\"collapsed\" : true"), "encoded loop keeps repeatCount and collapsed")
    check(try WorkflowCodec.decode(reencoded) == wf, "encode → decode round trip is identical")
} catch { check(false, "loop JSON: \(error)") }

// MARK: 5. Failures, disabled steps, validation

section("5. Failure handling")
do {
    var wf = loaded["workflow_if_else_example.json"]!
    wf.steps[0].value = "Wrong title"                   // verify equals fails
    let app = MockLoginApp()
    let report = fastEngine(app).run(wf)
    check(!report.passed, "a failing verify fails the workflow")
    check(report.results.filter { $0.status == .skipped }.count == wf.totalStepCount - 1, "every later step (incl. nested) is reported SKIP")
    let msg = report.results.first { $0.status == .failed }?.message ?? ""
    check(msg.contains("expected \"Wrong title\", found \"Login\""), "failure message: \(msg)")

    var wf2 = loaded["workflow_if_else_example.json"]!
    wf2.steps[3].enabled = false                       // skip the switch toggle
    let app2 = MockLoginApp()
    let report2 = fastEngine(app2, log: false).run(wf2)
    check(!report2.passed, "disabled toggle → 'Remember me: On' verify fails as expected")
    check(report2.results.first { $0.step.id == "4" }?.status == .skipped, "disabled step reported SKIP")
}

section("6. Validation (bad files are rejected with a clear message)")
func expectInvalid(_ json: String, _ expected: String) {
    do { _ = try WorkflowCodec.decode(Data(json.utf8)); check(false, "should reject: \(expected)") }
    catch { check(error.localizedDescription.contains(expected), "rejected: \(error.localizedDescription)") }
}
expectInvalid(#"{"version":3,"name":"x","steps":[]}"#, "version 3 is not supported")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","type":"button","identifier":"a"},{"id":"1","type":"button","identifier":"b"}]}"#, "used more than once")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","kind":"if","type":"button","identifier":"a","then":[{"id":"1","type":"button","identifier":"b"}]}]}"#, "used more than once")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","type":"textField","identifier":"a","action":"typeText"}]}"#, "'typeText' needs a value")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","type":"staticText","identifier":"a","action":"typeText","value":"v"}]}"#, "not supported for 'staticText'")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","type":"slider","identifier":"a","action":"adjustSlider","value":"2"}]}"#, "between 0 and 1")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","kind":"loop","repeatCount":0,"steps":[]}]}"#, "repeatCount between 1 and 10000")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","kind":"if","type":"button","identifier":"a","condition":"equals"}]}"#, "'if equals' needs a value")
expectInvalid(#"{"version":2,"name":"x","steps":[{"id":"1","type":"button","identifier":"  "}]}"#, "empty accessibility identifier")

// MARK: 7. Element / action tables

section("7. Element types and actions")
check(ElementType.allCases.count == 81, "\(ElementType.allCases.count) XCUIElement types")
check(Set(ElementType.allCases.map(\.rawValue)).count == 81, "raw values unique")
check(ElementType.allCases.allSatisfy { $0.supportedActions.first == $0.defaultAction && $0.supportedActions.contains(.verify) },
      "every type: default action first, verify supported")
check(ActionType.allCases.allSatisfy { action in ElementType.allCases.contains { $0.supportedActions.contains(action) } },
      "every action is usable by some element type")
check(ElementType.allCases.allSatisfy { ElementType(dragPayload: $0.dragPayload) == $0 }, "palette drag payloads round-trip")
check(DragItem(payload: DragItem.loopBlock.payload) == .loopBlock && DragItem(payload: DragItem.ifBlock.payload) == .ifBlock,
      "If / Loop block payloads round-trip")

// MARK: 8. Editor model (what the Authoring Tool writes)

section("8. Authoring Tool model → JSON → back")
do {
    var tree = SampleWorkflows.login.steps.map { UIElement(step: $0) }
    func build(_ t: [UIElement]) -> Workflow {
        Workflow(name: "t", bundleIdentifier: "b", steps: t.enumerated().map { $1.toStep(id: String($0 + 1)) })
    }
    let wf = build(tree)
    try WorkflowCodec.validate(wf)
    check(true, "Login Sample builds a valid workflow")
    check(wf.steps[5].thenSteps?.map(\.id) == ["6.T1", "6.T2"] && wf.steps[5].elseSteps?.map(\.id) == ["6.E1"],
          "nested ids 6.T1, 6.T2, 6.E1")
    check(tree.numbered().map(\.number) == ["1", "2", "3", "4", "5", "6", "6.T1", "6.T2", "6.E1"], "display numbers match ids")

    // Simulate drag & drop: add a loop at the end, move step 4 (switch) into it, then the loop into THEN of the if.
    let loop = UIElement.makeLoop(repeatCount: 2, displayText: "Toggle twice")
    tree.insertStep(loop, at: .root(tree.count))
    let switchID = tree[3].id
    let removed = tree.removeStep(switchID)!.0
    check(tree.insertStep(removed, at: StepLocation(parentID: loop.id, branch: .loopBody, index: 0)), "drop step into Loop DO")
    let ifID = tree.first { $0.isIf }!.id
    let movedLoop = tree.removeStep(loop.id)!.0
    check(tree.insertStep(movedLoop, at: StepLocation(parentID: ifID, branch: .thenBranch, index: 0)), "drop Loop into THEN")
    check(!tree.insertStep(removed, at: StepLocation(parentID: switchID, branch: .thenBranch, index: 0)),
          "cannot drop into a non-block step")
    check(tree.updateStep(loop.id) { $0.displayText = "Renamed loop" } && tree.findStep(loop.id)?.displayText == "Renamed loop", "rename")
    tree.updateStep(ifID) { $0.isCollapsed = true }

    let wf2 = build(tree)
    try WorkflowCodec.validate(wf2)
    let numbers = tree.numbered().map(\.number)
    check(numbers == ["1", "2", "3", "4", "5", "5.T1", "5.T1.L1", "5.T2", "5.T3", "5.E1"], "renumbered: \(numbers.joined(separator: " "))")
    let data = try WorkflowCodec.encode(wf2)
    let back = try WorkflowCodec.decode(data).steps.map { UIElement(step: $0) }
    let ifBack = back[4]
    check(ifBack.isCollapsed && ifBack.thenSteps[0].isLoop && ifBack.thenSteps[0].displayText == "Renamed loop"
          && ifBack.thenSteps[0].repeatCount == 2 && ifBack.thenSteps[0].loopSteps[0].identifier == "remember_switch",
          "saved JSON reopens with the same tree, names, collapse state and loop count")

    // And the moved workflow still runs: switch toggled twice inside THEN → remember stays Off before login? (toggle happens after login, on home screen → fails)
    let dup = tree.findStep(ifID)!.duplicated()
    check(dup.id != ifID && dup.thenSteps[0].id != tree.findStep(ifID)!.thenSteps[0].id, "duplicate gives fresh ids to nested steps")
} catch { check(false, "editor model: \(error)") }

print("\n\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
