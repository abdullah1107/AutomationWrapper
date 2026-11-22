//
//  WorkflowRunner.swift
//  Headless entry point of the Execution Tool. It has no UI of its own: it loads
//  workflow.json, launches the app under test by bundle identifier, and executes
//  the steps in sequence.
//
//  Inputs (environment, normally set by run_workflow.sh):
//    WORKFLOW_PATH     absolute path to the workflow JSON (default: bundled login_workflow.json)
//    TARGET_BUNDLE_ID  overrides the JSON's "bundleIdentifier"
//
//  The target app must already be installed on the simulator/device.
//

import XCTest

final class WorkflowRunner: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testExecuteWorkflow() throws {
        let url = try WorkflowSource.resolveURL(in: Bundle(for: WorkflowRunner.self))
        let workflow = try WorkflowLoader().load(from: url)
        let bundleID = try WorkflowSource.targetBundleIdentifier(for: workflow)

        print("[WORKFLOW] File:   \(url.path)")
        print("[WORKFLOW] Target: \(bundleID)")

        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launch()

        let engine = WorkflowEngine(driver: XCUITestDriver(app: app))
        engine.stepWrapper = { title, body in
            XCTContext.runActivity(named: title) { _ in body() }
        }
        engine.onStepFailure = { [weak self] step, _ in
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Failure – step \(step.id) (\(step.identifier))"
            screenshot.lifetime = .keepAlways
            self?.add(screenshot)
        }

        let report = engine.run(workflow)

        let reportAttachment = XCTAttachment(string: report.summary)
        reportAttachment.name = "Execution report"
        reportAttachment.lifetime = .keepAlways
        add(reportAttachment)

        XCTAssertTrue(report.passed, report.summary)
    }
}
