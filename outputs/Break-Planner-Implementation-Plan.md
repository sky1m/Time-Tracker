# Break Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS app for planning employee breaks from each workday’s shift times, with subway-map styling, lettered stops, and live countdowns.

**Architecture:** A SwiftUI app stores employees and dated shifts locally with SwiftData. A pure schedule calculator derives break stops from shift duration; focused SwiftUI screens let the user manage employees and shifts, view routes and countdowns, and choose an appearance.

**Tech Stack:** Swift, SwiftUI, SwiftData, Foundation `Date`/`Calendar`, Xcode and iOS Simulator.

**Spec:** `outputs/Break-Planner-Design.md`

## Global Constraints

- Native iOS app using SwiftUI.
- NYC subway route-map visual language, with a light map appearance and a user-selectable dark appearance. Use transit-inspired colored lines and circular letter markers; do not depend on official MTA logos.
- Employees are entered once. Their shift start and end times are entered separately for each workday.
- Save employee and shift data locally on the iPhone.
- Choose the break plan from each shift’s duration.
- Label the shift start A, then label break stops B onward in chronological order. The stop letter identifies the position in that shift’s route, so a 6-hour shift’s first stop B is lunch and a longer shift can continue through E or F.
- For shifts of 5 hours or less, schedule one 15-minute rest break at +2 hours.
- For shifts over 5 and through 6 hours, schedule a 30-minute meal at +2 hours and a 15-minute rest break at +4 hours.
- For shifts over 6 and through 10 hours, schedule a 15-minute rest at +2 hours, a 30-minute meal at +4 hours, and a 15-minute rest at +6 hours.
- For shifts over 10 and through 14 hours, schedule rest at +2 hours, meal at +4 hours, rest at +6 hours, meal at +8 hours, and rest at +10 hours; rest periods last 15 minutes and meals last 30 minutes.
- Do not show a break whose start time is at or after the shift end. Shifts longer than 14 hours show that no automatic route is available.
- Treat an end time earlier than a shift’s start time as occurring on the following calendar day; reject identical start and end times.
- Update countdowns while the app is in the foreground and recalculate them when it returns to the foreground.

## Review Focus

- Duration boundaries at 5 hours, just over 5, 6, just over 6, 10, just over 10, 14, and over 14; manually verify the selected stop counts and order in Task 5.
- Overnight shifts such as 9:00 PM–5:00 AM; manually verify the route crosses midnight and keeps its workday date in Task 5.
- Invalid identical start/end times and an end time earlier than start; manually verify rejection versus next-day interpretation in Task 2.
- Time before a break, during each break, after the final break, and after shift end; manually verify countdown, active-break, no-more-stops, and complete states in Task 5.
- Two employees with different shifts on the same date and different shifts on separate dates; manually verify independent routes and saved data after relaunch in Task 5.

---

## File Map

- `BreakPlanner.xcodeproj/` — iOS app project and build settings.
- `BreakPlanner/BreakPlannerApp.swift` — app entry point and SwiftData model container.
- `BreakPlanner/Models/Employee.swift` — locally persisted employee name and identity.
- `BreakPlanner/Models/Shift.swift` — employee relationship, workday date, start, and end.
- `BreakPlanner/Scheduling/BreakSchedule.swift` — shift interval, stop kinds, stop values, and duration-based stop calculation.
- `BreakPlanner/Scheduling/ShiftCountdown.swift` — pure route status for upcoming, active, no-more-stops, complete, and unsupported shifts.
- `BreakPlanner/Views/TeamScheduleView.swift` — selected workday roster and entry points; starts as an empty root placeholder in Task 1.
- `BreakPlanner/Views/EmployeeFormView.swift` — add/edit employee name.
- `BreakPlanner/Views/ShiftFormView.swift` — add/edit a dated shift for an employee.
- `BreakPlanner/Views/ShiftRouteView.swift` — connected route and live countdown.
- `BreakPlanner/Theme/TransitTheme.swift` — route colors, letter markers, and light/dark palette.

## Tasks

### Task 1: Create the iOS project and schedule domain

**Files:**
- Create: `BreakPlanner.xcodeproj/`
- Create: `BreakPlanner/BreakPlannerApp.swift`
- Create: `BreakPlanner/Models/Employee.swift`
- Create: `BreakPlanner/Models/Shift.swift`
- Create: `BreakPlanner/Scheduling/BreakSchedule.swift`
- Create: `BreakPlanner/Views/TeamScheduleView.swift`

**Interfaces:**
- Produces `Employee`, a SwiftData model with `id: UUID` and `name: String`.
- Produces `Shift`, a SwiftData model with `id: UUID`, `workday: Date`, `startsAt: Date`, `endsAt: Date`, and `employee: Employee?`.
- Produces `ShiftInterval(startsAt: Date, endsAt: Date)`.
- Produces `BreakKind` with `.rest` and `.meal` cases.
- Produces `BreakStop(letter: String, kind: BreakKind, startsAt: Date, durationMinutes: Int)` with a derived `endsAt: Date`.
- Produces `BreakScheduleCalculator.stops(for shift: ShiftInterval) -> [BreakStop]`.

- [ ] **Step 1: Create the Xcode iOS App project**

  In Xcode, create an iOS App named `BreakPlanner` in this workspace, select the SwiftUI lifecycle, and set the deployment target to iOS 17 or later for SwiftData. Create the source groups and paths listed in the File Map.

- [ ] **Step 2: Add the SwiftData models**

  Define `Employee` and `Shift` with the properties in the Interfaces block. Make a shift refer to its employee and keep `workday` separate from its absolute start/end dates so overnight shifts remain associated with the day they begin.

- [ ] **Step 3: Add the schedule value types and calculator**

  Implement `BreakScheduleCalculator.stops(for:)` using elapsed shift duration. Use the exact duration bands and stop offsets from Global Constraints. Assign letters B onward in order, use 15 minutes for rest stops and 30 minutes for meal stops, omit stops at or after `endsAt`, and return no automatic stops for shifts longer than 14 hours or invalid intervals.

- [ ] **Step 4: Connect SwiftData to the app entry point and build**

  Register `Employee` and `Shift` in `.modelContainer` in `BreakPlannerApp.swift`, and launch an empty `TeamScheduleView` placeholder. Before using the iOS SDK, stop and have the user review and accept the Xcode/Apple SDK license in Terminal with `sudo xcodebuild -license`; do not accept it on the user’s behalf. Then run `xcodebuild -project BreakPlanner.xcodeproj -scheme BreakPlanner -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.

  Expected: `BUILD SUCCEEDED`.

### Task 2: Add employees and per-workday shifts

**Files:**
- Modify: `BreakPlanner/Views/TeamScheduleView.swift`
- Create: `BreakPlanner/Views/EmployeeFormView.swift`
- Create: `BreakPlanner/Views/ShiftFormView.swift`
- Modify: `BreakPlanner/BreakPlannerApp.swift`

**Interfaces:**
- Consumes `Employee`, `Shift`, and `BreakScheduleCalculator` from Task 1.
- Produces `EmployeeFormView(employee: Employee?, onSaved: () -> Void)` for adding or editing a name.
- Produces `ShiftFormView(employee: Employee, shift: Shift?, workday: Date, onSaved: () -> Void)` for adding or editing that employee’s shift for one date.
- Produces `TeamScheduleView`, which owns the selected workday and lists its employees and shifts.

- [ ] **Step 1: Render the selected-workday team list**

  Query saved employees and shifts, filter shifts by selected `workday` using `Calendar.current.startOfDay(for:)`, and show each employee with that date’s start/end times. Show an empty state when no employees or no shifts exist for the selected date.

- [ ] **Step 2: Add and edit employees**

  Implement `EmployeeFormView` with a required trimmed name. Save new employees and edits through the SwiftData `modelContext`; dismiss only after a successful save.

- [ ] **Step 3: Add and edit dated shifts**

  Implement `ShiftFormView` with a workday date, start time, and end time. Combine the selected date and times into absolute dates. If the chosen end clock time is earlier than the start, use the following calendar day; reject equal times and show a clear validation message.

- [ ] **Step 4: Wire roster actions and persist shifts**

  Add “Add Employee” and per-employee “Add Shift” actions, plus edit actions for existing entries. Save shifts with their employee relationship and workday date.

- [ ] **Step 5: Build the app target**

  Run the Task 1 `xcodebuild` command.

  Expected: `BUILD SUCCEEDED`.

### Task 3: Add route detail and time-until countdown

**Files:**
- Create: `BreakPlanner/Scheduling/ShiftCountdown.swift`
- Create: `BreakPlanner/Views/ShiftRouteView.swift`
- Modify: `BreakPlanner/Views/TeamScheduleView.swift`

**Interfaces:**
- Consumes `ShiftInterval`, `BreakStop`, and `BreakScheduleCalculator.stops(for:)` from Task 1.
- Produces `ShiftCountdownState` with `.until(stop: BreakStop, secondsRemaining: Int)`, `.active(stop: BreakStop, secondsRemaining: Int)`, `.noMoreStops(shiftEnd: Date, secondsRemaining: Int)`, `.complete`, and `.unsupportedDuration` cases.
- Produces `ShiftCountdown.state(for shift: ShiftInterval, now: Date) -> ShiftCountdownState`.
- Produces `ShiftRouteView(shift: Shift)`.

- [ ] **Step 1: Implement route status calculation**

  In `ShiftCountdown.swift`, return `.complete` when `now >= endsAt`; otherwise return the active break and seconds until it ends, the next upcoming stop and seconds until it starts, `.noMoreStops` with the countdown to shift end, or `.unsupportedDuration` when the shift exceeds 14 hours.

- [ ] **Step 2: Render the connected shift route**

  In `ShiftRouteView.swift`, render A at shift start and each computed letter stop with its clock time, kind, and duration. Render the current route state using the exact text “Time til next stop” for upcoming breaks; show active-break remaining time, no-more-stops time to shift end, and “Shift complete” in their respective states.

- [ ] **Step 3: Add a foreground-updating countdown**

  Use `TimelineView(.periodic(from: .now, by: 1))` in `ShiftRouteView` and pass its current date to `ShiftCountdown.state(for:now:)`. On foreground resume, calculate from the current date rather than a stored countdown value.

- [ ] **Step 4: Open the selected employee’s route**

  Connect a team row to `ShiftRouteView` for that employee’s shift on the selected date. Keep each row’s next stop and countdown derived from its own shift.

- [ ] **Step 5: Build the app target**

  Run the Task 1 `xcodebuild` command.

  Expected: `BUILD SUCCEEDED`.

### Task 4: Apply the NYC route-map style and dark mode

**Files:**
- Create: `BreakPlanner/Theme/TransitTheme.swift`
- Modify: `BreakPlanner/BreakPlannerApp.swift`
- Modify: `BreakPlanner/Views/TeamScheduleView.swift`
- Modify: `BreakPlanner/Views/EmployeeFormView.swift`
- Modify: `BreakPlanner/Views/ShiftFormView.swift`
- Modify: `BreakPlanner/Views/ShiftRouteView.swift`

**Interfaces:**
- Produces `TransitTheme` palette values for route colors, backgrounds, text, and stop badges.
- Produces a persisted appearance selection with Light and Dark values, applied at the app root.

- [ ] **Step 1: Define route-map palette and stop styling**

  Add transit-inspired colored route lines and circular letter badges in `TransitTheme.swift`. Give badges a contrasting border and keep stop labels readable without relying on color alone.

- [ ] **Step 2: Add the appearance control**

  Store the selected Light/Dark value with `@AppStorage("appearanceMode")`, default to Light, and apply `.preferredColorScheme` at the app root.

- [ ] **Step 3: Apply the palette to app screens**

  Replace temporary system-independent colors in the roster, forms, and route view with theme values. Add a Light/Dark toggle to the team schedule and preserve its selection after relaunch.

- [ ] **Step 4: Build the app target**

  Run the Task 1 `xcodebuild` command.

  Expected: `BUILD SUCCEEDED`.

### Task 5: Integrate and walk through the schedule cases

**Files:**
- Modify: `BreakPlanner/Views/TeamScheduleView.swift`
- Modify: `BreakPlanner/Views/ShiftFormView.swift`
- Modify: `BreakPlanner/Views/ShiftRouteView.swift`

**Interfaces:**
- Consumes the data, calculator, countdown, and theme interfaces from Tasks 1–4.
- Produces the complete first-version flow from employee entry through saved shift route.

- [ ] **Step 1: Build and launch in an iPhone Simulator**

  After the user has reviewed and accepted the Xcode/Apple SDK license, run the Task 1 build command and launch `BreakPlanner` in an available iPhone Simulator.

- [ ] **Step 2: Walk through every duration band**

  Enter shifts with durations 5:00, 5:01, 6:00, 6:01, 10:00, 10:01, 14:00, and more than 14:00. Confirm the stop counts, order, letters, offsets, and unsupported-duration state match Global Constraints.

- [ ] **Step 3: Walk through overnight and countdown states**

  Enter a 9:00 PM–5:00 AM shift and confirm stops at 11:00 PM, 1:00 AM, and 3:00 AM. Confirm the view shows the upcoming countdown, active break, post-final-break time to shift end, and complete state as simulated current time moves through the shift.

- [ ] **Step 4: Walk through employee/date persistence**

  Add two employees, give them different shifts on one date, and give one employee different times on another date. Close and relaunch the app; confirm employee names and dated shifts remain saved and routes remain independent.

- [ ] **Step 5: Walk through Light and Dark appearances**

  Switch appearances, inspect roster, forms, route colors, letters, and text for readable contrast, then relaunch and confirm the selected appearance persists.

## Execution Notes

- No Git repository exists in the workspace, so implementation commits are unavailable unless the project is moved into or initialized as a repository.
- Xcode 27.0 is installed, but the Xcode/Apple SDK license has not been accepted. The user must review and accept it before build or Simulator operations.
- Do not add automated tests as part of this plan; verify with Xcode builds and the Simulator walkthrough above.
