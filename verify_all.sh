#!/bin/bash
#
# verify_all.sh – checks the whole Wrapper + Automation setup on this Mac.
#
#   1. JSON + engine checks: compiles the shared JSON contract, the Execution Tool engine and the
#      Authoring Tool model with swiftc, then reads every workflow JSON and runs it against a mock
#      login app (THEN / ELSE branches, loops, failures, validation, save → reopen).
#   2. Builds the Authoring Tool (macOS app).
#   3. Builds the Execution Tool (XCUITest runner) for an iPhone simulator.
#   4. With --run: installs the demo login app and runs workflow_if_else_example.json on the simulator.
#
# Usage:
#   ./verify_all.sh            # steps 1–3
#   ./verify_all.sh --run      # steps 1–4 (real UI run on the simulator)
#
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
OUT="$ROOT/build/verify"
mkdir -p "$OUT"
RUN_SIM=false
[[ "${1:-}" == "--run" ]] && RUN_SIM=true

declare -a SUMMARY
result() { SUMMARY+=("$1  $2"); }

echo "=================== 1. JSON + engine checks ==================="
if swiftc -o "$OUT/workflow_checks" \
     Shared/WorkflowContract.swift \
     ExecutionTool/ExecutionTool/Engine/*.swift \
     ExecutionTool/ExecutionTool/Driver/UIAutomationDriver.swift \
     AuthoringTool/AuthoringTool/Domain/UIElement.swift \
     "AuthoringTool/AuthoringTool/Domain/ElementType+Editor.swift" \
     AuthoringTool/AuthoringTool/Domain/SampleWorkflows.swift \
     Tests/WorkflowChecks/*.swift > "$OUT/checks_compile.log" 2>&1; then
  if "$OUT/workflow_checks" "$ROOT" | tee "$OUT/checks.log"; then
    result "PASS" "JSON + engine checks ($(tail -1 "$OUT/checks.log"))"
  else
    result "FAIL" "JSON + engine checks – see build/verify/checks.log"
  fi
else
  cat "$OUT/checks_compile.log"
  result "FAIL" "JSON + engine checks did not compile – see build/verify/checks_compile.log"
fi

echo
echo "=================== 2. Build Authoring Tool (macOS) ==================="
if xcodebuild build \
     -project AuthoringTool/AuthoringTool.xcodeproj \
     -scheme AuthoringTool \
     -destination 'platform=macOS' \
     -derivedDataPath "$OUT/DerivedData" > "$OUT/authoring_build.log" 2>&1; then
  result "PASS" "Authoring Tool builds"
else
  grep -E "error:|warning: .*deprecated" "$OUT/authoring_build.log" | sort -u | head -40
  result "FAIL" "Authoring Tool build – see build/verify/authoring_build.log"
fi

echo
echo "=================== 3. Build Execution Tool (XCUITest runner) ==================="
UDID="${SIMULATOR_UDID:-}"
[[ -z "$UDID" ]] && UDID="$(xcrun simctl list devices available | grep 'iPhone' | grep '(Booted)' | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
[[ -z "$UDID" ]] && UDID="$(xcrun simctl list devices available | grep 'iPhone' | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
if [[ -z "$UDID" ]]; then
  result "FAIL" "No iPhone simulator found (Xcode > Settings > Platforms)"
elif xcodebuild build-for-testing \
       -project ExecutionTool/ExecutionTool.xcodeproj \
       -scheme ExecutionTool \
       -destination "id=$UDID" \
       -derivedDataPath "$OUT/DerivedData" > "$OUT/execution_build.log" 2>&1; then
  result "PASS" "Execution Tool builds (simulator $UDID)"
else
  grep -E "error:" "$OUT/execution_build.log" | sort -u | head -40
  result "FAIL" "Execution Tool build – see build/verify/execution_build.log"
fi

if $RUN_SIM && [[ -n "$UDID" ]]; then
  echo
  echo "=================== 4. Run workflow_if_else_example.json on the simulator ==================="
  if SampleTargetApp/install_on_simulator.sh "$UDID" > "$OUT/install.log" 2>&1; then
    if SIMULATOR_UDID="$UDID" ExecutionTool/run_workflow.sh "$ROOT/workflow_if_else_example.json" --udid "$UDID"; then
      result "PASS" "workflow_if_else_example.json ran on the simulator"
    else
      result "FAIL" "Simulator run – see ExecutionTool/build/last_run.log"
    fi
  else
    tail -20 "$OUT/install.log"
    result "FAIL" "Could not install SampleLoginApp – see build/verify/install.log"
  fi
fi

echo
echo "=================== Summary ==================="
STATUS=0
for line in "${SUMMARY[@]}"; do
  echo "$line"
  [[ "$line" == FAIL* ]] && STATUS=1
done
exit $STATUS
