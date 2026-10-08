# Break Planner Team Live Activities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a complete employee roster and one scheduled countdown Live Activity for each eligible employee shift.

**Architecture:** Keep SwiftData as the source of employee and shift data. Add a WidgetKit extension with shared ActivityKit attributes, an app-side coordinator that schedules and reconciles activities from saved shifts, and a roster presentation that remains useful when Live Activities are unavailable. The local-only app refreshes activity state when it enters the foreground; it does not promise background progression or dismissal.

**Tech Stack:** Swift, SwiftUI, SwiftData, ActivityKit, WidgetKit, Xcode, iOS 17 deployment target.

**Spec:** `outputs/Break-Planner-Live-Activities-Spec.md`

## Global Constraints

- Keep the existing SwiftData employee records; employee names remain saved and reusable across workdays.
- Show every saved employee for the selected workday, including employees without a shift.
- Provide one ActivityKit Live Activity per employee shift, subject to system limits.
- On iOS 26 and later, schedule each future activity when its shift is saved while the app is open; it starts at the saved shift start with the system start alert.
- On iOS 17–25, retain the in-app future-shift countdown and start its Live Activity when the app next opens during that shift.
- Reconcile activity state when the app returns to the foreground.
- Show employee name, shift range, next stop letter/type/time, and a countdown.
- Do not use a server, account, or push-notification service.
- Preserve iOS 17 deployment target and existing subway theme, shift rules, and local persistence.
- If Live Activities are unavailable or refused, keep the in-app roster and countdown usable.

## Review Focus

- Multiple activities and device/system limits: failed requests must leave the roster functional and report the activity limitation to the user.
- Duplicate scheduling after shift edits or repeated foreground reconciliation: one shift ID must map to at most one activity.
- Shift already in progress when saved or restored: start an activity immediately with the actual next stop or shift-end target.
- Overnight shift and workday boundary: scheduled start and activity reconciliation must use absolute shift dates.
- Break begins or shift ends while the app stays closed: show a truthful expired countdown until reconciliation; do not claim automatic advancement or dismissal.

---

## File Map

- `BreakPlanner.xcodeproj/project.pbxproj` — add the Widget Extension target, embed its appex in the app, and set target deployment/build settings.
- `BreakPlanner/Shared/BreakActivityAttributes.swift` — shared `ActivityAttributes` contract with stable employee/shift IDs and content state for the displayed next event.
- `BreakPlannerWidgets/BreakPlannerLiveActivity.swift` — `ActivityConfiguration` Lock Screen layout and supported Dynamic Island regions.
- `BreakPlannerWidgets/BreakPlannerWidgetsBundle.swift` — WidgetKit extension entry point.
- `BreakPlanner/Scheduling/BreakActivityCoordinator.swift` — request, update, reconcile, and end activities from saved shifts.
- `BreakPlanner/Views/TeamScheduleView.swift` — preserve every saved employee in the master roster and show next stop details/countdowns and Live Activity availability.
- `BreakPlanner/Views/ShiftFormView.swift` — invoke activity scheduling/reconciliation only after a successful shift save.
- `BreakPlanner/BreakPlannerApp.swift` — reconcile activities when the scene returns to the foreground.

## Tasks

### Task 1: Add the Widget Extension and shared Live Activity contract

**Files:**
- Modify: `BreakPlanner.xcodeproj/project.pbxproj`
- Create: `BreakPlanner/Shared/BreakActivityAttributes.swift`
- Create: `BreakPlannerWidgets/BreakPlannerLiveActivity.swift`
- Create: `BreakPlannerWidgets/BreakPlannerWidgetsBundle.swift`

**Interfaces:**
- `BreakActivityAttributes: ActivityAttributes` exposes immutable `employeeID: UUID`, `shiftID: UUID`, `employeeName: String`, `shiftStartsAt: Date`, and `shiftEndsAt: Date`.
- `BreakActivityAttributes.ContentState: Codable, Hashable` exposes `eventTitle: String`, `eventLetter: String?`, `eventKind: String?`, `eventStartsAt: Date`, and `eventEndsAt: Date`.
- The Widget Extension renders a countdown to `eventStartsAt` for a future break, or the event end when the activity represents an active break; when there are no breaks left, it renders the shift-end event.

- [ ] **Step 1: Add a Widget Extension target**

Create an iOS Widget Extension named `BreakPlannerWidgets`, embed it in `BreakPlanner`, set its minimum deployment target to iOS 17, and make the shared attributes file available to both targets without including the app’s SwiftData views in the extension.

Expected: Xcode project contains app and Widget Extension targets with the extension embedded in the app.

- [ ] **Step 2: Define the shared ActivityKit attributes**

Add `BreakActivityAttributes` with the exact properties above. Keep employee/shift identity and shift dates immutable attributes; keep the currently displayed event in `ContentState` so the app can update it after foreground reconciliation.

Expected: App and extension compile against one identical `ActivityAttributes` type.

- [ ] **Step 3: Render Lock Screen and Dynamic Island states**

Implement `ActivityConfiguration(for: BreakActivityAttributes.self)` in `BreakPlannerLiveActivity.swift`. Use transit-style letter markers, readable labels, the employee name, shift range, and a system-rendered countdown. Provide compact, minimal, and expanded Dynamic Island regions. Do not depend on app process updates for the timer itself.

Expected: Widget Extension builds and has a complete Lock Screen presentation plus Dynamic Island layouts supported on the device.

- [ ] **Step 4: Add the WidgetKit extension entry point and build**

Register `BreakPlannerLiveActivity` from `BreakPlannerWidgetsBundle.swift`. Build the app and extension targets with signing disabled for the simulator destination.

Run: `xcodebuild -project BreakPlanner.xcodeproj -scheme BreakPlanner -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

Expected: `BUILD SUCCEEDED`.

### Task 2: Implement activity scheduling and foreground reconciliation

**Files:**
- Create: `BreakPlanner/Scheduling/BreakActivityCoordinator.swift`
- Modify: `BreakPlanner/Views/ShiftFormView.swift`
- Modify: `BreakPlanner/BreakPlannerApp.swift`

**Interfaces:**
- `@MainActor final class BreakActivityCoordinator` provides `func scheduleOrUpdate(shift: Shift, now: Date = .now) async -> ActivitySchedulingResult` and `func reconcile(shifts: [Shift], now: Date = .now) async`.
- `ActivitySchedulingResult` distinguishes `.scheduled`, `.updated`, `.waitingForShift`, `.alreadyEnded`, `.disabled`, and `.failed(String)` for roster feedback.
- The coordinator is observable by SwiftUI and exposes `private(set) var resultsByShiftID: [UUID: ActivitySchedulingResult]` so each row can display the latest scheduling result.
- `BreakActivityCoordinator` derives `ContentState` from `ShiftCountdown.state(for:now:)` and uses `BreakScheduleCalculator.stops(for:)` for event duration and route labels.

- [ ] **Step 1: Add deterministic next-event state mapping**

Implement a private mapper for `ShiftCountdownState`: `.until` maps to the upcoming stop’s start date; `.active` maps to that stop’s end date and identifies the active break; `.noMoreStops` maps to shift end; `.complete` marks the shift finished; `.unsupportedDuration` maps to the existing unsupported-route presentation.

Expected: each activity state contains the exact event title, optional route letter/type, and absolute event start/end dates for the current time.

- [ ] **Step 2: Schedule or update one activity per shift**

Find existing activities by `shiftID` and update them instead of creating duplicates. On iOS 26 and later, future shifts use `pushType: nil`, `style: .standard`, `AlertConfiguration(title: "Break Planner", body: "<employee name>'s shift is starting.", sound: .default)`, and `start: shift.startsAt` with `Activity.request(attributes:content:pushType:style:alertConfiguration:start:)`. On iOS 17–25, return `.waitingForShift` for a future shift without requesting an activity; foreground reconciliation starts it once active. For active shifts on iOS 17+, use the immediate-start overload supported by that OS with no push type. Check `ActivityAuthorizationInfo().areActivitiesEnabled`; catch ActivityKit request errors and return `.disabled` or `.failed(String)`.

Expected: repeated calls for the same shift do not create duplicate activities, and rejected requests return a UI-consumable result.

- [ ] **Step 3: Reconcile persisted shifts and stale activities**

Implement `reconcile(shifts:now:)` to update activities matched to saved shifts, create eligible missing activities, and end activities whose shifts are deleted or complete. Use stable shift IDs for matching. Do not end a shift activity solely because the app’s currently selected workday changed.

Expected: foreground reconciliation repairs app-closed transitions and preserves activities for all current/future saved shifts within system limits.

- [ ] **Step 4: Connect shift save and app foreground lifecycle**

After `ShiftFormView` successfully saves, call `scheduleOrUpdate(shift:)`; never schedule after a failed save. In `BreakPlannerApp` or the root view, fetch persisted shifts and call `reconcile(shifts:now:)` when `scenePhase` becomes `.active`.

Expected: a newly saved future shift is scheduled immediately on iOS 26+, and returns `.waitingForShift` on iOS 17–25; returning to the app starts eligible active shifts, refreshes activities, and ends completed/deleted ones.

### Task 3: Upgrade the master roster for team-wide countdowns and activity status

**Files:**
- Modify: `BreakPlanner/Views/TeamScheduleView.swift`
- Modify: `BreakPlanner/Scheduling/BreakActivityCoordinator.swift`

**Interfaces:**
- A roster row continues to consume `Employee`, the selected workday’s optional `Shift`, and `ShiftCountdown.state(for:now:)`.
- The coordinator exposes an activity request status keyed by `shiftID` for the current process so the roster can show when the system did not allow an activity.

- [ ] **Step 1: Keep the roster complete for the selected workday**

Render all saved employees independent of whether `workdayShifts` is empty. For each employee with a shift, show shift range and next stop route letter/type/time plus live countdown; for each employee without a shift, show “No shift assigned” and the existing Add Shift action.

Expected: selecting a day with no shifts still displays every saved employee and their no-shift state.

- [ ] **Step 2: Surface Live Activity limitations without blocking scheduling**

Show a concise per-shift status when Live Activities are disabled or the system refuses the request. Keep route navigation, countdowns, employee edits, and shift edits usable. Do not imply that every employee has an activity if ActivityKit rejected one.

Expected: roster truthfully communicates unavailable activities while remaining fully functional.

- [ ] **Step 3: Preserve theme and foreground countdown behavior**

Use the existing transit palette and appearance setting; keep text and letter markers legible in both modes. Keep the master countdown updated while foregrounded and recompute it after app activation.

Expected: the expanded team roster retains current light/dark behavior and countdown accuracy.

### Task 4: Build and statically review the Live Activity integration

**Files:**
- Modify as needed: files listed in Tasks 1–3.

- [ ] **Step 1: Build app and extension together**

Run: `xcodebuild -project BreakPlanner.xcodeproj -scheme BreakPlanner -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

Expected: app and extension compile successfully.

- [ ] **Step 2: Inspect app and extension configuration**

Confirm the generated app Info.plist contains `NSSupportsLiveActivities = YES`, the extension plist has `NSExtensionPointIdentifier = com.apple.widgetkit-extension`, both targets support iOS 17, and no frequent-push-updates setting or remote-push dependency was added.

Expected: app/extension configuration enables local Live Activities while retaining the iOS 17 deployment target and no push service.

- [ ] **Step 3: Statically review state and lifecycle paths**

Review the full change for the future iOS 26 scheduled-start branch; the iOS 17–25 `.waitingForShift` path and foreground start; active-break/shift-end countdown target mapping; duplicate prevention; edited/deleted/completed shift reconciliation; disabled/refused activity fallback; and overnight absolute dates. Do not run automated or manual runtime tests unless the user asks.

Expected: source/configuration evidence covers each path in `outputs/Break-Planner-Live-Activities-Spec.md`; report runtime behavior as unverified because no device/simulator exercise was authorized.
