# QA Matrix: VisionClaw iPhone + OpenClaw

## Scope
This matrix validates Milestone 1 + 1.5 behavior for iPhone-first VisionClaw with OpenClaw tool-calling and voice-only fallback.

## Entry Conditions
- App baseline from upstream `1559f9c`.
- iPhone on iOS 17+ with camera/mic permissions controllable.
- Meta AI app available for Developer Mode flow.
- OpenClaw endpoint configured in app settings when testing tool paths.

## Test Matrix

| ID | Scenario | Setup | Steps | Expected Result |
|---|---|---|---|---|
| QA-001 | Happy path: glasses + Gemini + OpenClaw | Glasses connected, OpenClaw reachable | Start streaming -> start AI -> ask 3 action requests (shopping, message, web lookup) | Audio conversation works, all 3 tool tasks complete with spoken confirmations |
| QA-002 | OpenClaw unreachable fallback | Set invalid host/port or stop gateway | Start AI and ask action task | Session stays active, no deadlock, UI shows action tools unavailable and voice-only mode |
| QA-003 | OpenClaw not configured fallback | Clear gateway settings | Start AI and ask action task | Session remains usable for voice/vision Q&A; explicit no-tools messaging shown |
| QA-004 | Gemini disconnect resilience | Force network drop during active session | Observe app during disconnect and recovery attempt | User sees disconnect message; app resets session cleanly without crash |
| QA-005 | OpenClaw timeout behavior | Slow/blocked gateway path | Ask action task | Tool call fails with timeout-style error; conversation continues |
| QA-006 | Developer Mode missing | Meta AI Developer Mode off | Attempt glasses registration flow | Registration failure surfaced with actionable error |
| QA-007 | Camera/mic permissions denied | Deny permissions in iOS settings | Start iPhone mode and AI session | App shows actionable permission guidance; no crash |
| QA-008 | Mode stability | Repeated start/stop cycles | Start/stop stream and AI 10x | No crash, no stuck state, state indicators consistent |

## Double-Check Gate Requirements
Before marking QA pass:
1. All upstream reliability patches merged (ToolMode + UI fallback + bridge guardrails).
2. Evidence attached for each scenario (timestamped notes/screen captures/log snippets).
3. Any P0/P1 defects moved to blocker log with mitigation before release recommendation.

## Evidence Template
For each test row:
- Run timestamp:
- Device/build:
- Result: Pass/Fail
- Evidence path:
- Notes:

## Exit Criteria
- Required pass: QA-001 through QA-005.
- Conditional pass: QA-006 through QA-008 (environment dependent but must be documented).
- No unresolved P0/P1 issues for Milestone 1.5 target.
