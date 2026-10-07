# Break Planner — Team Live Activities

## Goal

Extend the existing native iOS Break Planner so a manager can see a team-wide view of every saved employee and each employee with a shift can have a Live Activity counting down to the next break.

## Approved behavior

- Keep the existing SwiftData employee records. Employee names remain saved and reusable across workdays; do not create duplicate employee records when adding a new dated shift.
- Enhance the existing Team Schedule into the master roster: show every saved employee for the selected workday, including employees without a shift. For employees with shifts, show the shift, next route stop letter/type/time, and countdown. Employees without shifts show “No shift assigned.”
- Provide one ActivityKit Live Activity per employee shift, using the employee and shift identity so shifts on different dates do not collide.
- Schedule each activity when its shift is saved while the app is open. On iOS 26 and later, schedule a future activity to start automatically at the saved shift start. On iOS 17–25, keep the future-shift countdown in the app and start its Live Activity when the app next opens during that shift. Reconcile saved current/future shifts when the app returns to the foreground. A shift already in progress when reconciled starts an activity immediately; ended shifts do not start one.
- Show the employee name, shift time range, the next break or meal’s existing route letter and type, its scheduled time, and a live countdown. Keep the transit-inspired letter/color style legible in light and dark appearance. Provide Lock Screen and Dynamic Island presentations where iOS supports them.
- When the countdown reaches a break, refresh the next stop when the app is opened or returns to the foreground. The first version is local-only: it does not use a server or push notifications to advance Live Activity state while the app stays closed.
- iOS 26 scheduled Live Activity start uses the system start alert required by the scheduled-start API. User-disabled Live Activities, unsupported devices, or system activity limits must not prevent use of the in-app roster and countdown. On iOS 17–25, explain that a future shift’s activity starts only after the app is opened during the shift.
- On foreground reconciliation, update activities for edited shifts, advance them to the next stop, and end them for completed or deleted shifts. If the app remains closed, an activity may show an expired countdown or remain visible until iOS dismisses it or the app next reconciles it; automatic state changes and guaranteed dismissal while closed are out of scope without a push service.
- Request one activity per eligible shift and handle ActivityKit rejection/limits gracefully; do not promise unlimited simultaneous activities. The master roster remains the complete team view even if iOS cannot host an activity for every employee.

## Out of scope

- Remote server, account, or push-notification service.
- Notifications when each break begins.
- Editing a shift from the Live Activity.
- Changing employee names or the break schedule rules approved in the original spec.

## Architecture

- Add an ActivityKit `ActivityAttributes` type and a WidgetKit extension containing the Live Activity Lock Screen and Dynamic Island layouts.
- Keep `Employee` and `Shift` as the source of truth in the existing local SwiftData store. Persist no separate employee-name copy for activities; include the employee display name and stable IDs in each activity’s attributes/content as needed for rendering and reconciliation.
- Add an app-side activity coordinator that requests scheduled activities on shift save, reconciles them against saved shifts when the scene becomes active, updates them after shift edits, and ends them when a shift is deleted or has completed while the app is active.
- Derive the current next stop from the existing shift schedule calculator and current time. Use an absolute event date for the countdown so the system can render the timer without per-second app updates.
- Keep activity refresh best-effort under ActivityKit and system limits. The in-app Team Schedule remains authoritative and updates while foregrounded.
- Preserve the current iOS 17 deployment target; confirm APIs and widget target settings during implementation.

## Acceptance checks

- Existing employee names remain available after app relaunch and can be selected for shifts on multiple workdays.
- The master roster lists all saved employees for a selected day, with shift details/countdown for scheduled employees and an explicit no-shift state for others.
- Saving a future shift while the app is open schedules one associated Live Activity to begin at shift start and shows its start alert on iOS 26 and later.
- On iOS 17–25, saving a future shift keeps the in-app countdown available and reports that opening the app during the shift is needed to start its Live Activity; opening the app during the shift starts it immediately.
- Saving a shift that is already active creates an activity immediately with the next scheduled break countdown.
- The Live Activity displays the correct employee, shift, next route letter/type/time, and a ticking countdown in Lock Screen and supported Dynamic Island layouts.
- When the app returns to the foreground after a break time, the activity advances to the next planned stop; after the final stop, it counts down to shift end; after shift end, foreground reconciliation ends it.
- Editing a shift updates the associated activity without creating duplicates; deleting a shift ends its activity at next reconciliation.
- A shift with no remaining stops shows the shift-end target. Unsupported shifts follow the existing unsupported-route behavior.
- If Live Activities are disabled or the system refuses an activity because of limits, the in-app roster and countdown continue to work and the app communicates that the activity could not be scheduled.
- Activity scheduling handles overnight shifts and workday changes using the shift’s absolute start/end dates.

## Platform references

- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Scheduling a Live Activity to start at a date](https://developer.apple.com/documentation/activitykit/activity/request%28attributes%3Acontent%3Apushtype%3Astyle%3Aalertconfiguration%3Astart%3A)
