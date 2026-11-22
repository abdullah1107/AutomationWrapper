# AutomationWrapper
```
Wrapper+Automation/
├── Shared/
│   └── WorkflowContract.swift     JSON schema (Workflow, AutomationStep, ElementType, ActionType,
│                                   ConditionType, StepKind)
│                                   + WorkflowCodec (encode / decode / validate / versioning)
├── AuthoringTool/                 1. macOS SwiftUI drag & drop editor (sequence only, no screen mock-up) → writes workflow.json
│   ├── AuthoringTool.xcodeproj
│   └── AuthoringTool/  Domain/ · ViewModels/ · Repository/ · Views/
├── ExecutionTool/                 2. Headless runner: reads workflow.json, executes the steps in sequence
│   ├── ExecutionTool.xcodeproj    (one XCUITest bundle, no app / UI of its own)
│   ├── run_workflow.sh            command-line entry point
│   └── ExecutionTool/
│       ├── WorkflowRunner.swift   loads JSON → launches target app by bundle id → runs engine
│       ├── Engine/   WorkflowLoader (JSON decoder) → WorkflowEngine → ActionResolver → StepHandlers
│       ├── Driver/   UIAutomationDriver (abstraction) → XCUITestDriver (XCUIApplication)
│       └── Workflows/login_workflow.json   bundled sample
└── SampleTargetApp/               Demo "app under test" for the login example (optional)
    ├── SampleLoginApp.xcodeproj
    ├── install_on_simulator.sh
    └── SampleLoginApp/
```
Requirements: Xcode 15 or later, macOS 13+, an iOS 16+ iPhone simulator.

## How it works

AutomationWrapper has two halves that share one JSON contract (`Shared/WorkflowContract.swift`).
The **Authoring Tool** (macOS) writes `workflow.json`. The **Execution Tool** (headless XCUITest)
reads it and drives an app that is already installed on an iOS Simulator.

**Colour key** (used in every diagram below):

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TB
    subgraph ROW1[" "]
        direction LR
        K1["🖥️ <b>Authoring Tool</b>"]:::author ~~~ K2["📄 <b>Workflow JSON</b>"]:::data ~~~ K3["⌨️ <b>Script / CLI</b>"]:::cli ~~~ K4["⚙️ <b>Engine</b>"]:::engine
    end
    subgraph ROW2[" "]
        direction LR
        K5["🔌 <b>Driver</b>"]:::driver ~~~ K6["📱 <b>App under test</b>"]:::app ~~~ K11["📊 <b>Output</b>"]:::out ~~~ K12["🔀 <b>Branch</b>"]:::branch
    end
    subgraph ROW3[" "]
        direction LR
        K7(["▶️ <b>Start / End</b>"]):::term ~~~ K8{{"❓ <b>Decision</b>"}}:::decide ~~~ K9(["✅ <b>Pass</b>"]):::pass ~~~ K10(["❌ <b>Fail</b>"]):::fail
    end
    ROW1 ~~~ ROW2
    ROW2 ~~~ ROW3
    class ROW1,ROW2,ROW3 sg_none

    classDef author fill:#EDE9FE,stroke:#7C3AED,stroke-width:2px,color:#2E1065
    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef driver fill:#FFEDD5,stroke:#EA580C,stroke-width:2px,color:#431407
    classDef app fill:#FCE7F3,stroke:#DB2777,stroke-width:2px,color:#500724
    classDef out fill:#F1F5F9,stroke:#475569,stroke-width:2px,color:#0F172A
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    classDef pass fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#052E16
    classDef fail fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A
    classDef branch fill:#E0F2FE,stroke:#0284C7,stroke-width:2px,color:#082F49
    classDef term fill:#4F46E5,stroke:#3730A3,stroke-width:2px,color:#FFFFFF
    classDef sg_none fill:none,stroke:none
```

Thick indigo arrows show the main path, green arrows lead to a pass, red arrows lead to a failure.

### 1. The big picture

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TB
    subgraph DESIGN["🖥️ Design time · macOS"]
        direction LR
        AT["<b>Authoring Tool</b><br/>drag & drop editor"]:::author
        JSON[("📄 <b>workflow.json</b><br/>shared JSON contract")]:::data
        AT == "💾 Save" ==> JSON
        JSON -. "📂 Open" .-> AT
    end

    RUN["⌨️ <b>run_workflow.sh</b><br/>→ <b>xcodebuild test</b><br/>picks simulator<br/>passes file + bundle id"]:::cli

    subgraph SIM["📱 Run time · iOS Simulator"]
        direction LR
        ET["⚙️ <b>Execution Tool</b><br/>headless XCUITest"]:::engine
        APP["📱 <b>App under test</b><br/>e.g. SampleLoginApp"]:::app
        ET == "tap · type<br/>swipe · verify" ==> APP
    end

    OUT["📊 <b>Results</b><br/>live step log<br/>last_run.log · .xcresult<br/>screenshots · exit code"]:::out

    DESIGN == "workflow.json" ==> RUN
    RUN ==> SIM
    SIM --> OUT

    class DESIGN sg_author
    class SIM sg_app

    classDef author fill:#EDE9FE,stroke:#7C3AED,stroke-width:2px,color:#2E1065
    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef app fill:#FCE7F3,stroke:#DB2777,stroke-width:2px,color:#500724
    classDef out fill:#F1F5F9,stroke:#475569,stroke-width:2px,color:#0F172A
    classDef sg_author fill:#F5F3FF,stroke:#A78BFA,stroke-width:2px,stroke-dasharray:6 4,color:#5B21B6
    classDef sg_app fill:#FDF2F8,stroke:#F472B6,stroke-width:2px,stroke-dasharray:6 4,color:#9D174D
    linkStyle 1,5 stroke:#64748B,stroke-width:2px
    linkStyle 0,2,3,4 stroke:#4F46E5,stroke-width:3.5px
```

Both Xcode projects compile the same `WorkflowContract.swift`, so the writer and the reader can never
disagree about the JSON format.

### 2. End-to-end flow

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","actorBkg":"#FFFFFF","actorBorder":"#6366F1","actorTextColor":"#1E1B4B","actorLineColor":"#94A3B8","signalColor":"#334155","signalTextColor":"#0F172A","labelBoxBkgColor":"#4F46E5","labelBoxBorderColor":"#4F46E5","labelTextColor":"#FFFFFF","loopTextColor":"#134E4A","noteBkgColor":"#FFFFFF","noteBorderColor":"#94A3B8","noteTextColor":"#0F172A","sequenceNumberColor":"#FFFFFF","activationBkgColor":"#99F6E4","activationBorderColor":"#0D9488"},"sequence":{"actorMargin":30,"width":130,"messageMargin":30,"wrap":true}}}%%
sequenceDiagram
    autonumber
    box rgb(248,250,252)
        actor U as 👤 User
        participant AT as 🖥️ Authoring Tool
        participant F as 📄 workflow.json
        participant SH as ⌨️ run_workflow.sh<br/>+ xcodebuild
        participant WR as 🧪 WorkflowRunner
        participant EN as ⚙️ WorkflowEngine
        participant DR as 🔌 XCUITestDriver
        participant APP as 📱 App under test
    end

    rect rgb(237,233,254)
        Note over U,F: ① DESIGN · build the workflow
        U->>AT: drag steps,<br/>set bundle id
        AT->>F: 💾 save
    end

    rect rgb(219,234,254)
        Note over U,APP: ② LAUNCH · start the runner and the app
        U->>SH: run workflow.json
        SH->>SH: check JSON,<br/>pick simulator
        SH->>WR: xcodebuild test
        WR->>F: load + validate
        WR->>APP: 🚀 launch by bundle id
    end

    rect rgb(204,251,241)
        Note over WR,APP: ③ EXECUTE · run every step in order
        WR->>+EN: run(workflow)
        loop every step, top to bottom
            EN->>DR: tap · type · check
            DR->>APP: find + gesture
            APP-->>DR: element state
            DR-->>EN: ok / error
            EN-->>SH: live RUN / PASS / FAIL line
        end
        EN-->>-WR: 📊 ExecutionReport
    end

    rect rgb(254,249,195)
        Note over U,WR: ④ REPORT · result and exit code
        alt ✅ every step passed
            WR-->>SH: test passed
            SH-->>U: ✅ PASSED · exit 0
        else ❌ a step failed
            WR-->>SH: failed + screenshots
            SH-->>U: ❌ FAILED · exit 1+
        end
    end
```

### 3. Inside the Authoring Tool

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TB
    subgraph VIEWS["🖥️ SwiftUI views"]
        PAL["🎨 <b>PaletteView</b><br/>81 element types<br/>+ If / Else + Loop blocks"]:::author
        SEQ["📋 <b>SequenceView</b><br/>START → steps → END<br/>drag · drop · nest · wrap"]:::author
        INS["🛠️ <b>InspectorView</b><br/>identifier · action · condition<br/>value · timeout · wait time"]:::author
        PRE["👁️ <b>JSONPreviewView</b><br/>live JSON"]:::author
    end

    VM["🧠 <b>EditorViewModel</b><br/>elements: [UIElement]"]:::author
    BUILD["🔢 <b>buildWorkflow()</b><br/>UIElement → AutomationStep<br/>ids 1 · 2 · 6.T1 · 6.E1 · 7.L1"]:::author

    REPO["🗂️ <b>WorkflowRepository</b>"]:::data
    CODEC["✔️ <b>WorkflowCodec</b> (Shared)<br/>validate · encode · decode"]:::data
    FILE[("📄 <b>workflow.json</b>")]:::data

    PAL -- "drag in" --> SEQ
    SEQ -- "edits" --> VM
    INS -- "edits" --> VM
    VM -- "preview" --> PRE
    VM == "💾 Save ⌘S" ==> BUILD
    BUILD ==> REPO
    REPO ==> CODEC
    CODEC == "atomic write" ==> FILE
    FILE -. "📂 Open ⌘O" .-> REPO
    REPO -. "apply(workflow)" .-> VM

    class VIEWS sg_author

    classDef author fill:#EDE9FE,stroke:#7C3AED,stroke-width:2px,color:#2E1065
    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef sg_author fill:#F5F3FF,stroke:#A78BFA,stroke-width:2px,stroke-dasharray:6 4,color:#5B21B6
    linkStyle 0,1,2,3,8,9 stroke:#64748B,stroke-width:2px
    linkStyle 4,5,6,7 stroke:#4F46E5,stroke-width:3.5px
```

### 4. What `run_workflow.sh` does

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TD
    START(["▶️ <b>run_workflow.sh</b><br/>workflow.json<br/>--bundle-id · --udid"]):::term
    P{"workflow path<br/>given?"}:::decide
    V{"file exists and<br/>is valid JSON?"}:::decide
    BUN["📦 runner uses bundled<br/><b>login_workflow.json</b>"]:::data
    PICK["📱 <b>Pick simulator</b><br/>--udid → booted iPhone → first iPhone"]:::app
    FOUND{"simulator<br/>found?"}:::decide
    XB["🔨 <b>xcodebuild test</b><br/>WorkflowRunner/testExecuteWorkflow<br/>TEST_RUNNER_WORKFLOW_PATH<br/>TEST_RUNNER_TARGET_BUNDLE_ID"]:::cli
    LOG["📜 <b>tee build/last_run.log</b><br/>prints [WORKFLOW] lines live"]:::out
    ST{"test<br/>status?"}:::decide
    PASS(["✅ <b>RESULT: PASSED</b><br/>exit 0"]):::pass
    HINT["💡 hint if the app<br/>is not installed"]:::out
    FAIL(["❌ <b>RESULT: FAILED</b><br/>exit non-zero"]):::fail
    E1(["❌ <b>exit 1</b><br/>bad workflow file"]):::fail
    E2(["❌ <b>exit 1</b><br/>no iPhone simulator"]):::fail

    START ==> P
    P == "yes" ==> V
    P -- "no" --> BUN
    V -- "no" --> E1
    V == "yes" ==> PICK
    BUN --> PICK
    PICK ==> FOUND
    FOUND -- "no" --> E2
    FOUND == "yes" ==> XB
    XB ==> LOG
    LOG ==> ST
    ST -- "0" --> PASS
    ST -- "non-zero" --> HINT
    HINT --> FAIL

    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef app fill:#FCE7F3,stroke:#DB2777,stroke-width:2px,color:#500724
    classDef out fill:#F1F5F9,stroke:#475569,stroke-width:2px,color:#0F172A
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    classDef pass fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#052E16
    classDef fail fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A
    classDef term fill:#4F46E5,stroke:#3730A3,stroke-width:2px,color:#FFFFFF
    linkStyle 2,5 stroke:#64748B,stroke-width:2px
    linkStyle 0,1,4,6,8,9,10 stroke:#4F46E5,stroke-width:3.5px
    linkStyle 11 stroke:#16A34A,stroke-width:3px,color:#166534
    linkStyle 3,7,12,13 stroke:#DC2626,stroke-width:3px,color:#991B1B
```

### 5. Inside the Execution Tool

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TB
    subgraph ENTRY["🧪 Entry point · XCTest"]
        WR["▶️ <b>WorkflowRunner</b><br/>testExecuteWorkflow()"]:::cli
        SRC["🧭 <b>WorkflowSource</b><br/>file: WORKFLOW_PATH or bundled JSON<br/>app: TARGET_BUNDLE_ID or JSON bundleIdentifier"]:::cli
        LD["📄 <b>WorkflowLoader</b><br/>read → decode → validate"]:::data
    end

    subgraph ENGINE["⚙️ Engine · plain Swift, no XCTest"]
        EN["⚙️ <b>WorkflowEngine</b><br/>order · if / else · loops · waits<br/>stopOnFailure · live log"]:::engine
        AR["🔁 <b>ActionResolver</b><br/>element type → handler<br/>2 retries · 10s first try · 3s retries"]:::engine
        SH["🎯 <b>StandardStepHandler</b><br/>one per element type"]:::engine
        CE["🔍 <b>ConditionEvaluator</b><br/>re-checks every 0.25s"]:::engine
        REP["📊 <b>ExecutionReport</b><br/>PASS · FAIL · SKIP per step"]:::out
    end

    subgraph DRIVER["🔌 Driver layer"]
        DRV["🔌 <b>UIAutomationDriver</b><br/>protocol"]:::driver
        XD["📲 <b>XCUITestDriver</b><br/>real UI via XCUIApplication"]:::driver
        MK["🧪 <b>MockLoginApp</b><br/>fake app for verify_all.sh"]:::driver
    end

    APP["📱 <b>App under test</b>"]:::app

    WR ==> SRC
    SRC ==> LD
    LD ==> EN
    EN == "action steps" ==> AR
    AR ==> SH
    EN -- "if steps" --> CE
    SH -- "verify steps" --> CE
    SH ==> DRV
    CE --> DRV
    DRV == "real run" ==> XD
    DRV -. "tests" .-> MK
    XD ==> APP
    EN --> REP
    REP -. "XCTAssert(report.passed)" .-> WR

    class ENTRY sg_cli
    class ENGINE sg_engine
    class DRIVER sg_driver

    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef driver fill:#FFEDD5,stroke:#EA580C,stroke-width:2px,color:#431407
    classDef app fill:#FCE7F3,stroke:#DB2777,stroke-width:2px,color:#500724
    classDef out fill:#F1F5F9,stroke:#475569,stroke-width:2px,color:#0F172A
    classDef sg_cli fill:#EFF6FF,stroke:#60A5FA,stroke-width:2px,stroke-dasharray:6 4,color:#1E40AF
    classDef sg_engine fill:#F0FDFA,stroke:#2DD4BF,stroke-width:2px,stroke-dasharray:6 4,color:#115E59
    classDef sg_driver fill:#FFF7ED,stroke:#FB923C,stroke-width:2px,stroke-dasharray:6 4,color:#9A3412
    linkStyle 5,6,8,10,12,13 stroke:#64748B,stroke-width:2px
    linkStyle 0,1,2,3,4,7,9,11 stroke:#4F46E5,stroke-width:3.5px
```

Everything in the engine box is plain Swift with no XCTest dependency. That is why `verify_all.sh` can run
the whole engine against `MockLoginApp` without a simulator, and why another backend (for example Appium)
only needs a new `UIAutomationDriver`.

### 6. How the engine runs each step

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TD
    NEXT(["▶️ <b>next step</b>"]):::term
    H{"halted earlier, or<br/>enabled = false?"}:::decide
    SKIP["⏭️ <b>SKIP</b><br/>this step + nested steps"]:::out
    K{"step<br/>kind?"}:::decide

    subgraph ACTION["🎯 action step"]
        A1["<b>ActionResolver.perform</b><br/>handler for type + action"]:::engine
        A2{"worked?"}:::decide
        A3["🔁 wait 0.5s<br/>retry with 3s timeout"]:::engine
        A4(["✅ <b>PASS</b><br/>then pause waitTime"]):::pass
        A5(["❌ <b>FAIL</b><br/>screenshot attached"]):::fail
        A6{"stopOnFailure?"}:::decide
        A7["🛑 <b>halt</b><br/>remaining steps skipped"]:::fail
    end

    subgraph IFB["🔀 if step"]
        I1["🔍 <b>ConditionEvaluator</b><br/>step timeout, default 3s"]:::engine
        I2{"condition<br/>true?"}:::decide
        I3["run <b>THEN</b> steps<br/>same flow, nested"]:::branch
        I4["run <b>ELSE</b> steps<br/>same flow, nested"]:::branch
    end

    subgraph LOOPB["🔁 loop step"]
        L1["run <b>DO</b> steps × repeatCount<br/>stop early if halted"]:::branch
    end

    DONE(["⏩ <b>more steps?</b> → next step<br/>🏁 none left → RESULT: PASSED / FAILED"]):::term

    NEXT ==> H
    H -- "yes" --> SKIP
    SKIP --> DONE
    H == "no" ==> K
    K == "action" ==> A1
    K -- "if" --> I1
    K -- "loop" --> L1
    A1 ==> A2
    A2 -- "no · retries left" --> A3
    A3 --> A1
    A2 -- "yes" --> A4
    A2 -- "no · out of retries" --> A5
    A4 --> DONE
    A5 --> A6
    A6 -- "yes (default)" --> A7
    A6 -- "no" --> DONE
    A7 --> DONE
    I1 --> I2
    I2 -- "yes" --> I3
    I2 -- "no" --> I4
    I3 --> DONE
    I4 --> DONE
    L1 --> DONE

    class ACTION sg_engine
    class IFB sg_branch
    class LOOPB sg_driver

    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef out fill:#F1F5F9,stroke:#475569,stroke-width:2px,color:#0F172A
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    classDef pass fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#052E16
    classDef fail fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A
    classDef branch fill:#E0F2FE,stroke:#0284C7,stroke-width:2px,color:#082F49
    classDef term fill:#4F46E5,stroke:#3730A3,stroke-width:2px,color:#FFFFFF
    classDef sg_engine fill:#F0FDFA,stroke:#2DD4BF,stroke-width:2px,stroke-dasharray:6 4,color:#115E59
    classDef sg_driver fill:#FFF7ED,stroke:#FB923C,stroke-width:2px,stroke-dasharray:6 4,color:#9A3412
    classDef sg_branch fill:#F0F9FF,stroke:#38BDF8,stroke-width:2px,stroke-dasharray:6 4,color:#075985
    linkStyle 1,2,5,6,8,9,12,13,15,16,17,18,19,20,21,22 stroke:#64748B,stroke-width:2px
    linkStyle 0,3,4,7 stroke:#4F46E5,stroke-width:3.5px
    linkStyle 10 stroke:#16A34A,stroke-width:3px,color:#166534
    linkStyle 11,14 stroke:#DC2626,stroke-width:3px,color:#991B1B
```

### 7. How a condition is checked (`verify` and `if`)

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TD
    C["📝 <b>condition</b><br/>if missing: equals when a value<br/>is set, else exists"]:::data
    SEC{"secureTextField<br/>+ equals / contains?"}:::decide
    EX["🔒 check <b>exists</b> instead<br/>secure text can't be read"]:::driver
    SNAP["📸 <b>driver.snapshot</b><br/>text · enabled<br/>selected · hittable"]:::driver
    CMP{"condition<br/>true?"}:::decide
    TO{"timeout<br/>reached?"}:::decide
    T(["✅ <b>true</b><br/>verify → PASS<br/>if → THEN"]):::pass
    F(["❌ <b>false</b><br/>verify → FAIL<br/>if → ELSE"]):::fail

    C ==> SEC
    SEC -- "yes" --> EX
    EX --> SNAP
    SEC == "no" ==> SNAP
    SNAP ==> CMP
    CMP -- "yes" --> T
    CMP -- "no" --> TO
    TO -- "no · wait 0.25s" --> SNAP
    TO -- "yes" --> F

    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef driver fill:#FFEDD5,stroke:#EA580C,stroke-width:2px,color:#431407
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    classDef pass fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#052E16
    classDef fail fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A
    linkStyle 1,2,6,7 stroke:#64748B,stroke-width:2px
    linkStyle 0,3,4 stroke:#4F46E5,stroke-width:3.5px
    linkStyle 5 stroke:#16A34A,stroke-width:3px,color:#166534
    linkStyle 8 stroke:#DC2626,stroke-width:3px,color:#991B1B
```

### 8. How `XCUITestDriver` finds an element

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TD
    L["🎯 <b>locator</b><br/>type + identifier"]:::engine
    Q["🔎 search by <b>type + identifier</b><br/>wait up to the step timeout"]:::driver
    W{"found?"}:::decide
    FB{"🔎 any element type<br/>with that identifier?"}:::decide
    NF(["❌ <b>elementNotFound</b>"]):::fail
    EL["✔️ <b>element</b>"]:::driver
    G{"tap, press<br/>or type?"}:::decide
    HIT{"hittable<br/>within 3s?"}:::decide
    NH(["❌ <b>notHittable</b>"]):::fail
    ACT(["✅ <b>perform action</b>"]):::pass

    L ==> Q
    Q ==> W
    W == "yes" ==> EL
    W -- "no" --> FB
    FB -- "yes" --> EL
    FB -- "no" --> NF
    EL ==> G
    G -- "yes" --> HIT
    G -- "no: swipe, toggle,<br/>slider, picker, read" --> ACT
    HIT -- "yes" --> ACT
    HIT -- "no" --> NH

    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef driver fill:#FFEDD5,stroke:#EA580C,stroke-width:2px,color:#431407
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    classDef pass fill:#DCFCE7,stroke:#16A34A,stroke-width:2px,color:#052E16
    classDef fail fill:#FEE2E2,stroke:#DC2626,stroke-width:2px,color:#450A0A
    linkStyle 3,4,7 stroke:#64748B,stroke-width:2px
    linkStyle 0,1,2,6 stroke:#4F46E5,stroke-width:3.5px
    linkStyle 8,9 stroke:#16A34A,stroke-width:3px,color:#166534
    linkStyle 5,10 stroke:#DC2626,stroke-width:3px,color:#991B1B
```

The fallback means a step still works when the app exposes an element with a different type than the
one chosen in the editor, as long as the accessibility identifier matches.

### 9. Example: the login workflow

`workflow_if_else_example.json` (and the Authoring Tool's Login Sample) runs like this against
`SampleLoginApp`:

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TD
    S(["▶️ <b>START</b><br/>launch com.example.automation.SampleLoginApp"]):::term
    S1["<b>1</b> · ✔️ <b>verify</b> login_title = 'Login'"]:::engine
    S2["<b>2</b> · ⌨️ <b>type</b> username_field<br/>john@example.com"]:::cli
    S3["<b>3</b> · ⌨️ <b>type</b> password_field<br/>•••••••••••"]:::cli
    S4["<b>4</b> · 🔘 <b>toggle</b> remember_switch"]:::cli
    S5["<b>5</b> · 👆 <b>tap</b> login_button · wait 2s"]:::cli
    S6{"<b>6</b> · <b>IF</b> welcome_label<br/>exists within 5s?"}:::decide

    subgraph THENB["✅ THEN · logged in"]
        T1["<b>6.T1</b> · ✔️ <b>verify</b> remember_status_label<br/>= 'Remember me: On'"]:::engine
        T2["<b>6.T2</b> · 👆 <b>tap</b> logout_button"]:::cli
    end

    subgraph ELSEB["❌ ELSE · login failed"]
        E1["<b>6.E1</b> · ✔️ <b>verify</b> error_label<br/>contains 'Invalid'"]:::engine
    end

    R(["🏁 <b>END</b> · RESULT: PASSED / FAILED"]):::term

    S ==> S1
    S1 ==> S2
    S2 ==> S3
    S3 ==> S4
    S4 ==> S5
    S5 ==> S6
    S6 -- "true" --> T1
    T1 --> T2
    T2 --> R
    S6 -- "false" --> E1
    E1 --> R

    class THENB sg_pass
    class ELSEB sg_fail

    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    classDef term fill:#4F46E5,stroke:#3730A3,stroke-width:2px,color:#FFFFFF
    classDef sg_pass fill:#F0FDF4,stroke:#4ADE80,stroke-width:2px,stroke-dasharray:6 4,color:#166534
    classDef sg_fail fill:#FEF2F2,stroke:#F87171,stroke-width:2px,stroke-dasharray:6 4,color:#991B1B
    linkStyle 0,1,2,3,4,5 stroke:#4F46E5,stroke-width:3.5px
    linkStyle 6,7,8 stroke:#16A34A,stroke-width:3px,color:#166534
    linkStyle 9,10 stroke:#DC2626,stroke-width:3px,color:#991B1B
```

Blue boxes act on the app, teal boxes check it.

### 10. The JSON model

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart LR
    WF["📄 <b>Workflow</b><br/>version: 2<br/>name<br/>bundleIdentifier<br/>steps: [ … ]"]:::data
    ST{{"🧩 <b>step</b><br/>id · label · enabled · waitTime<br/>kind = ?"}}:::decide
    ACT["🎯 <b>action</b> (default)<br/>type · identifier · action<br/>value · condition · timeout"]:::cli
    IFS["🔀 <b>if</b><br/>type · identifier<br/>condition · value · timeout<br/>then: [ … ]<br/>else: [ … ]"]:::engine
    LPS["🔁 <b>loop</b><br/>repeatCount<br/>1 to 10000<br/>steps: [ … ]"]:::driver

    WF == "steps" ==> ST
    ST == "kind: action" ==> ACT
    ST -- "kind: if" --> IFS
    ST -- "kind: loop" --> LPS
    IFS -. "then / else hold more steps" .-> ST
    LPS -. "steps hold more steps" .-> ST

    classDef data fill:#FEF3C7,stroke:#D97706,stroke-width:2px,color:#451A03
    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef driver fill:#FFEDD5,stroke:#EA580C,stroke-width:2px,color:#431407
    classDef decide fill:#FEF9C3,stroke:#CA8A04,stroke-width:2px,color:#422006
    linkStyle 2,3,4,5 stroke:#64748B,stroke-width:2px
    linkStyle 0,1 stroke:#4F46E5,stroke-width:3.5px
```

Only `id` is always required. Action and `if` steps also need `type` and `identifier`; loop steps need
`repeatCount`. `WorkflowCodec.validate` rejects files with a `version` above 2, duplicate step ids, empty
identifiers, actions the element type does not support, and missing or out-of-range values.

### 11. What `verify_all.sh` checks

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontSize":"15px","lineColor":"#64748B","primaryColor":"#F8FAFC","primaryTextColor":"#0F172A","primaryBorderColor":"#94A3B8","edgeLabelBackground":"#FFFFFF","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","titleColor":"#0F172A"}}}%%
flowchart TD
    V1["1️⃣ <b>Engine checks</b><br/>swiftc + Tests/WorkflowChecks<br/>every JSON vs MockLoginApp"]:::engine
    V2["2️⃣ <b>Build Authoring Tool</b><br/>macOS"]:::author
    V3["3️⃣ <b>Build Execution Tool</b><br/>iPhone simulator"]:::cli
    V4["4️⃣ <b>Real run</b> · only with --run<br/>install SampleLoginApp<br/>run workflow_if_else_example.json"]:::app
    SUM(["📋 <b>Summary</b><br/>exit 0 if nothing failed"]):::term

    V1 ==> V2
    V2 ==> V3
    V3 ==> SUM
    V3 -. "--run" .-> V4
    V4 -.-> SUM

    classDef author fill:#EDE9FE,stroke:#7C3AED,stroke-width:2px,color:#2E1065
    classDef cli fill:#DBEAFE,stroke:#2563EB,stroke-width:2px,color:#172554
    classDef engine fill:#CCFBF1,stroke:#0D9488,stroke-width:2px,color:#042F2E
    classDef app fill:#FCE7F3,stroke:#DB2777,stroke-width:2px,color:#500724
    classDef term fill:#4F46E5,stroke:#3730A3,stroke-width:2px,color:#FFFFFF
    linkStyle 3,4 stroke:#64748B,stroke-width:2px
    linkStyle 0,1,2 stroke:#4F46E5,stroke-width:3.5px
```

## 1. Authoring Tool

Open `AuthoringTool/AuthoringTool.xcodeproj` and run it on **My Mac**. The Login sample is loaded on launch.

- The palette lists **every XCUIElement type** (81, grouped and searchable) plus an **If / Else** logic block.
- The design area has no screen mock-up: it is the **execution sequence** itself, a vertical list of step
  cards from START to END that run top to bottom. Drag elements from the palette into it (or double-click a
  palette item to add it at the end).
- Edit the selected step in the **Properties Inspector**: element type, identifier, action, verify condition,
  value, timeout, wait time.
- The sequence is fully drag & drop. The order is the execution order:
  - drag a row to reorder it; drop it on another row to insert before that row
  - drag rows (or palette items) onto a block's **THEN** / **ELSE** header to put them in that branch, and
    drag them back out the same way. Whole If / Else blocks can be dragged and nested.
  - right-click a row: Duplicate, Wrap in If / Else, Enable / Disable, Move, Delete
- **If / Else block:** pick the element to check and a condition (Exists, Does Not Exist, Text Equals,
  Text Contains, Is Enabled / Disabled, Is Selected / On, Is Not Selected / Off, Is Hittable) and an optional
  timeout. THEN steps run when it is true, ELSE steps when it is false.
  *Wrap in If / Else* (⌥⌘I) turns "tap X" into "if X exists → tap X".
- **Loop block (for loop):** repeats the steps in its **DO** section N times (set REPEAT in the block or the
  inspector). *Wrap in Loop* repeats an existing step. Loops and If / Else blocks can be nested in each other.
- **Rename any step:** double-click it (or right-click → Rename…, or *Step Name* in the inspector). The name is
  saved as `label`.
- **Minimize / expand:** the chevron on an If / Else or Loop card hides or shows its contents
  ("3 steps hidden"). The buttons in the design area header (or ⌥⌘← / ⌥⌘→) minimize / expand all blocks.
- Set **App bundle identifier** in the toolbar. It tells the Execution Tool which app to drive.
- **Save** (⌘S) writes `workflow.json`. **Open** (⌘O) imports one back.

## 2. Execution Tool (headless)

The Execution Tool has no UI. It launches an app that is **already installed** on the simulator
(`XCUIApplication(bundleIdentifier:)`) and executes the workflow steps in order.

```bash
# one-time: install the demo login app on the simulator
SampleTargetApp/install_on_simulator.sh

# run the bundled login workflow
ExecutionTool/run_workflow.sh

# run a workflow saved by the Authoring Tool
ExecutionTool/run_workflow.sh ~/Desktop/workflow.json

# drive a different app than the JSON says, or pick a simulator
ExecutionTool/run_workflow.sh ~/Desktop/workflow.json --bundle-id com.mycompany.MyApp --udid <SIMULATOR-UDID>
```

Output is the live execution sequence:

```
Executing 'Login Flow with If / Else' – 6 steps (+3 inside if/else)
[1] RUN   verify staticText 'login_title' equals "Login"
[1] PASS  verify staticText 'login_title' equals "Login" (1.3s)
[2] RUN   typeText textField 'username_field' = "john@example.com"
[2] PASS  typeText textField 'username_field' = "john@example.com" (2.4s)
[3] RUN   typeText secureTextField 'password_field' = "•••••••••••"
...
[6] IF    staticText 'welcome_label' exists
[6] TRUE  staticText 'welcome_label' exists → THEN (2 steps)
  [6.T1] RUN   verify staticText 'remember_status_label' equals "Remember me: On"
  [6.T1] PASS  verify staticText 'remember_status_label' equals "Remember me: On" (0.4s)
  [6.T2] RUN   tap button 'logout_button'
  ...
[6] END IF
RESULT: PASSED
```

The script exits 0 on pass and non-zero on failure, so it can run in CI. The full log is in
`ExecutionTool/build/last_run.log`. The `.xcresult` bundle holds the per-step activities and failure screenshots.

**From Xcode instead:** open `ExecutionTool.xcodeproj`, select an iPhone simulator, and press ⌘U. To run your
own file, go to Edit Scheme → Test → Arguments and enable `WORKFLOW_PATH`.

### Which app and which file
| input              | source                                                                 |
|--------------------|------------------------------------------------------------------------|
| workflow file      | `WORKFLOW_PATH` (set by the script), else bundled `login_workflow.json` |
| target app         | `TARGET_BUNDLE_ID` (`--bundle-id`), else `"bundleIdentifier"` in JSON   |
| simulator          | `--udid`, else the booted iPhone, else the first available iPhone       |

The target app must already be installed on the simulator you run against. For your own app, run it once
from Xcode on that simulator, or use `xcrun simctl install <udid> MyApp.app`.

## Checking everything works

```bash
./verify_all.sh          # JSON + engine checks, build Authoring Tool, build Execution Tool
./verify_all.sh --run    # …and run workflow_if_else_example.json on the simulator
```

Step 1 compiles `Shared/` + the Execution Tool engine + the Authoring Tool model with `swiftc` and runs
`Tests/WorkflowChecks` against every workflow JSON (a mock login app stands in for the simulator).
Logs go to `build/verify/`.

## Login scenario

| # | type            | identifier              | action   | value            | wait |
|---|-----------------|-------------------------|----------|------------------|------|
| 1 | staticText      | `login_title`           | verify   | Login            | 1    |
| 2 | textField       | `username_field`        | typeText | john@example.com | 1    |
| 3 | secureTextField | `password_field`        | typeText | password123      | 1    |
| 4 | switch          | `remember_switch`       | toggle   |                  | 1    |
| 5 | button          | `login_button`          | tap      |                  | 2    |
| 6 | **if** staticText `welcome_label` exists (timeout 5) |  |  |  |  |
| 6.T1 | staticText   | `remember_status_label` | verify equals   | Remember me: On |  |
| 6.T2 | button       | `logout_button`         | tap             |                 | 1 |
| 6.E1 | staticText   | `error_label`           | verify contains | Invalid         |  |

The bundled `login_workflow.json` is the original flat version (6 = verify `welcome_label`,
7 = verify `remember_status_label`); the Authoring Tool's Login Sample and `workflow_if_else_example.json`
use the If / Else version above.

## JSON contract

```json
{
  "version": 2,
  "name": "Login Flow",
  "bundleIdentifier": "com.example.automation.SampleLoginApp",
  "steps": [
    { "id": "1", "type": "staticText", "identifier": "login_title", "action": "verify", "condition": "equals", "value": "Login" },
    { "id": "5", "type": "button", "identifier": "login_button", "action": "tap", "waitTime": 2 },
    { "id": "6", "kind": "if", "type": "staticText", "identifier": "welcome_label", "condition": "exists", "timeout": 5,
      "then": [ { "id": "6.T1", "type": "button", "identifier": "logout_button", "action": "tap" } ],
      "else": [ { "id": "6.E1", "type": "staticText", "identifier": "error_label", "action": "verify", "condition": "contains", "value": "Invalid" } ] }
  ]
}
```

A loop step:

```json
{ "id": "7", "kind": "loop", "label": "Scroll the list", "repeatCount": 3,
  "steps": [ { "id": "7.L1", "type": "table", "identifier": "items_table", "action": "swipeUp" } ] }
```

A full example is in `workflow_if_else_example.json`.

| field              | meaning                                                                                |
|--------------------|----------------------------------------------------------------------------------------|
| `bundleIdentifier` | app to drive (optional if passed with `--bundle-id`)                                   |
| `kind`             | `action` (default), `if` or `loop`                                                     |
| `type`             | any `XCUIElement.ElementType` name: `button`, `staticText`, `textField`, `switch`, `cell`, `slider`, `pickerWheel`, `alert`, `navigationBar`, `any`, … (81 types) |
| `identifier`       | accessibility identifier in the target app                                             |
| `action`           | `tap`, `doubleTap`, `longPress`, `twoFingerTap`, `typeText`, `clearText`, `toggle`, `adjustSlider`, `selectPickerValue`, `swipeUp/Down/Left/Right`, `verify` (optional; defaults per type) |
| `condition`        | for `verify` and `if`: `exists`, `notExists`, `equals`, `contains`, `enabled`, `disabled`, `selected`, `notSelected`, `hittable`. Missing = `equals` if there is a value, else `exists` |
| `value`            | text to type, expected text, long-press seconds, slider position 0–1, or picker value  |
| `timeout`          | seconds to wait for the element / condition (default 10 for actions, 3 for `if`)       |
| `then` / `else`    | `if` steps only: steps to run when the condition is true / false (can be nested)       |
| `repeatCount` / `steps` | `loop` steps only: run `steps` this many times (1–10000). Loops have no `type` / `identifier` |
| `label`, `collapsed` | step name and minimized state in the editor; ignored by the Execution Tool          |
| `waitTime`         | seconds to pause after the step succeeds                                               |
| `label`            | editor display name; ignored by the Execution Tool (`position` from older files is ignored too) |
| `enabled`          | `false` skips the step                                                                 |

Files with a `version` higher than `Workflow.currentVersion` (2) are rejected. Version 1 files still load.
Step ids must be unique across the whole tree; the Authoring Tool numbers nested steps `6.T1`, `6.E1`, `7.L1`, `6.T1.E2`, ….

## Extending

- **Element types:** every `XCUIElement.ElementType` is already in `ElementType` (Shared) and mapped in
  `XCUITestDriver` (`ElementType.xcuiType`). All of them use `StandardStepHandler`; to customise one, write a
  `StepHandler` and replace its entry in `ActionResolver.standard()`.
- **New action:** add a case to `ActionType` (Shared), handle it in `StandardStepHandler`, and, if it needs a new
  gesture, in `UIAutomationDriver` / `XCUITestDriver`.
- **Conditions:** `ConditionEvaluator` polls `UIAutomationDriver.snapshot(_:)` until the condition is true or
  the timeout runs out. `if` steps use it to choose a branch, `verify` steps to pass or fail.
- **Other backend:** implement `UIAutomationDriver` and pass it to `WorkflowEngine`.
- **Retries / timeouts:** `ActionResolver` (`maxRetries`, `elementTimeout`, `retryTimeout`).
- **Run every step even after a failure:** `WorkflowEngine(stopOnFailure: false)`.
