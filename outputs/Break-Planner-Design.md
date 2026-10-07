# iOS Break Planner — Design Spec

## Goal

Build an iOS app that helps plan breaks for a roster of employees. For each workday, the user can enter an employee’s shift start and end times and see that employee’s upcoming breaks and a live countdown to the next stop.

## Approved direction

- Native iOS app using SwiftUI.
- NYC subway route-map visual language, with a light map appearance and a user-selectable dark appearance. Use transit-inspired colored lines and circular letter markers; do not depend on official MTA logos.
- Employees are entered once. Their shift start and end times are entered separately for each workday.
- Save employee and shift data locally on the iPhone.
- Choose the break plan from each shift’s duration.
- Label the shift start A, then label break stops B onward in chronological order. The stop letter identifies the position in that shift’s route, so a 6-hour shift’s first stop B is lunch and a longer shift can continue through E or F.

## First-version screens

### Team schedule

Show the employee roster with each person’s shift for the selected workday. A row includes the employee’s name, shift start and end, the next stop’s letter, and the time remaining until that stop. Provide an action to add an employee and an action to add a shift for a selected employee and date. Selecting an employee opens their route for that shift.

### Employee entry

Collect an employee’s name. Allow the name to be edited later.

### Workday shift entry

Collect the workday date, shift start time, and shift end time for one employee. Times are entered per shift, so an employee can have different hours on different days. Support overnight shifts by treating an end time earlier than the start time as occurring on the following calendar day.

### Shift route

Show the shift as a connected route with A at shift start and subsequent letters at the calculated break times. Show the break duration and clock time at each stop. Show a prominent “Time til next stop” countdown. During a scheduled break, identify the active break and show its remaining duration; afterward, advance to the next upcoming stop. After the final break, show that there are no more stops and count down to shift end. Show “Shift complete” when the scheduled end time is reached.

### Appearance

Provide a Light/Dark control and remember the user’s selection. Keep station letters and labels legible in both appearances. Use text and letter markers in addition to color so the schedule remains understandable without color perception.

## Schedule calculation

Select a plan from shift duration, then calculate its break times from the shift start rather than from when the app is opened:

| Shift duration | Stop sequence from shift start | Break periods |
| --- | --- | --- |
| 5 hours or less | B · 15-minute rest at +2 hours | 1 rest break |
| More than 5 through 6 hours | B · 30-minute lunch at +2 hours; C · 15-minute rest at +4 hours | 1 meal, 1 rest break |
| More than 6 through 10 hours | B · 15-minute rest at +2 hours; C · 30-minute lunch at +4 hours; D · 15-minute rest at +6 hours | 1 meal, 2 rest breaks |
| More than 10 through 14 hours | B · 15-minute rest at +2 hours; C · 30-minute lunch at +4 hours; D · 15-minute rest at +6 hours; E · 30-minute lunch at +8 hours; F · 15-minute rest at +10 hours | 2 meals, 3 rest breaks |

The period counts come from the attached chart as the user requested. The user-defined timing is applied where specified: a 6-hour shift has lunch first at hour 2, followed by a 15-minute rest break at hour 4; an 8-hour shift retains the original hour-2, hour-4, and hour-6 schedule. For other duration bands, the stop sequence in the table places the chart’s period counts at two-hour intervals. Do not show a break whose start time is at or after the shift end. Calculate times using the device’s local calendar and time zone. Update the visible countdown while the app is in the foreground and recalculate it when the app returns to the foreground so it reflects the current time.

The chart covers shifts up to 14 hours. For shifts longer than 14 hours, show a clear message that no automatic route is available.

## Data and architecture

- `Employee`: stable identifier and display name.
- `Shift`: stable identifier, employee identifier, workday date, start date/time, and end date/time.
- Break stops are derived from a shift’s duration and are not stored as separate editable records in the first version.
- Use SwiftData for on-device persistence. No account or remote service is needed for the first version.
- Keep schedule arithmetic in a small value-type calculation layer that accepts a shift and current time and returns the ordered stops, active stop if any, and next countdown target. Keep SwiftUI views responsible for rendering and editing.

## Error handling and edge cases

- Require an employee name and valid start/end times before saving.
- Reject a shift with identical start and end times; allow an end time earlier than the start to represent an overnight shift.
- Show a clear empty state when the roster or selected workday has no entries.
- If a shift is edited, immediately recompute the route and countdown from its updated times.
- Overlapping employee shifts are allowed; each employee’s route is calculated independently.

## Acceptance checks

- A 5-hour shift starting at 9:00 AM displays one 15-minute break at 11:00 AM, labeled B.
- A 6-hour shift starting at 9:00 AM displays a 30-minute lunch at 11:00 AM, labeled B, then a 15-minute rest break at 1:00 PM, labeled C.
- An 8-hour shift starting at 9:00 AM displays a 15-minute rest break at 11:00 AM (B), a 30-minute lunch at 1:00 PM (C), and a 15-minute rest break at 3:00 PM (D).
- A 12-hour shift starting at 9:00 AM displays three 15-minute rests and two 30-minute meals at 11:00 AM (B), 1:00 PM (C), 3:00 PM (D), 5:00 PM (E), and 7:00 PM (F), respectively.
- After the last break, the route shows the countdown to shift end; it changes to “Shift complete” only when the shift end time is reached.
- A 9:00 PM–5:00 AM shift displays break times across midnight correctly.
- Shifts entered for different workdays can have different start and end times for the same employee, and the break plan is selected from each shift’s duration.
- Stops at or after the shift end are omitted.
- The countdown advances to the upcoming stop and reflects the current time after the app resumes.
- Employee names, shift times, letter labels, route colors, and appearance choice remain legible in Light and Dark modes.
- Saved employee and shift entries are present after closing and reopening the app on the same iPhone.

## Implementation approach

The recommended first version is a single-device SwiftUI app with local SwiftData storage. A cloud-backed roster would support shared editing across iPhones but requires accounts, a backend, and synchronization behavior that are outside the approved first-version scope. A web app could be opened on iOS but would give up the native app direction the user requested.

## Open implementation note

Xcode 27.0 is installed in this environment. Before using the iOS SDK or simulator, the user must review and accept the Xcode and Apple SDK license in Terminal with `sudo xcodebuild -license`. The design remains platform-native and ready for implementation after that step.
