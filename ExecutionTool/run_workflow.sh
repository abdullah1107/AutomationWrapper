#!/bin/bash
#
# run_workflow.sh – Execution Tool (headless).
# Reads a workflow.json and executes its steps in sequence against an app that is
# already installed on an iOS Simulator, using XCUITest.
#
# Usage:
#   ./run_workflow.sh                                   # bundled login_workflow.json
#   ./run_workflow.sh ~/Desktop/workflow.json           # workflow from the Authoring Tool
#   ./run_workflow.sh ~/Desktop/workflow.json --bundle-id com.mycompany.MyApp
#   ./run_workflow.sh ~/Desktop/workflow.json --udid <SIMULATOR-UDID>
#
# The target app is taken from --bundle-id, else from "bundleIdentifier" in the JSON.
# Simulator: --udid, else the booted iPhone simulator, else the first available iPhone.
#
set -euo pipefail
cd "$(dirname "$0")"

WORKFLOW=""
BUNDLE_ID=""
UDID="${SIMULATOR_UDID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --udid)      UDID="$2"; shift 2 ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    *)           WORKFLOW="$1"; shift ;;
  esac
done

if [[ -n "$WORKFLOW" ]]; then
  [[ -f "$WORKFLOW" ]] || { echo "error: workflow file not found: $WORKFLOW" >&2; exit 1; }
  WORKFLOW="$(cd "$(dirname "$WORKFLOW")" && pwd)/$(basename "$WORKFLOW")"
  python3 -m json.tool "$WORKFLOW" > /dev/null || { echo "error: $WORKFLOW is not valid JSON" >&2; exit 1; }
fi

if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | grep 'iPhone' | grep '(Booted)' | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
fi
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | grep 'iPhone' | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
fi
[[ -n "$UDID" ]] || { echo "error: no iPhone simulator found (Xcode > Settings > Platforms)." >&2; exit 1; }

echo "Workflow : ${WORKFLOW:-bundled ExecutionTool/Workflows/login_workflow.json}"
echo "Target   : ${BUNDLE_ID:-from JSON \"bundleIdentifier\"}"
echo "Simulator: $UDID"
echo "------------------------------------------------------------"

mkdir -p build
LOG="build/last_run.log"
RESULTS="build/Results-$(date +%Y%m%d-%H%M%S).xcresult"

# xcodebuild forwards TEST_RUNNER_<NAME> to the test runner as <NAME>.
set +e
TEST_RUNNER_WORKFLOW_PATH="$WORKFLOW" \
TEST_RUNNER_TARGET_BUNDLE_ID="$BUNDLE_ID" \
xcodebuild test \
  -project ExecutionTool.xcodeproj \
  -scheme ExecutionTool \
  -destination "id=$UDID" \
  -only-testing:ExecutionTool/WorkflowRunner/testExecuteWorkflow \
  -resultBundlePath "$RESULTS" 2>&1 \
  | tee "$LOG" \
  | grep --line-buffered -E '^\[WORKFLOW\]|error:' \
  | sed -u 's/^\[WORKFLOW\] //'
STATUS=${PIPESTATUS[0]}
set -e

echo "------------------------------------------------------------"
if [[ $STATUS -ne 0 ]] && grep -qiE 'not installed|Failed to launch|Application .* is not' "$LOG"; then
  echo "Hint: the target app is not installed on simulator $UDID."
  echo "      For the demo app run: ../SampleTargetApp/install_on_simulator.sh"
fi
echo "Full log: ExecutionTool/$LOG"
echo "Result bundle (screenshots, per-step activities): ExecutionTool/$RESULTS"
exit "$STATUS"
