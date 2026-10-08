import ActivityKit
import Foundation
import SwiftUI

enum ActivitySchedulingResult: Equatable {
    case scheduled
    case updated
    case waitingForShift
    case alreadyEnded
    case disabled
    case failed(String)

    var rosterMessage: String? {
        switch self {
        case .waitingForShift:
            return "Open the app during this shift to start its Live Activity."
        case .disabled:
            return "Live Activities are disabled on this device."
        case .failed(let reason):
            return "Live Activity could not start: \(reason)"
        case .scheduled, .updated, .alreadyEnded:
            return nil
        }
    }
}

@MainActor
final class BreakActivityCoordinator: ObservableObject {
    @Published private(set) var resultsByShiftID: [UUID: ActivitySchedulingResult] = [:]
    private var pendingByShiftID: [UUID: (token: UUID, task: Task<ActivitySchedulingResult, Never>)] = [:]

    func scheduleOrUpdate(shift: Shift, now: Date = .now) async -> ActivitySchedulingResult {
        let shiftID = shift.id
        let previous = pendingByShiftID[shiftID]?.task
        let token = UUID()
        let task = Task { @MainActor in
            _ = await previous?.value
            let result = await scheduleOrUpdateActivity(shift: shift, now: now)
            resultsByShiftID[shiftID] = result
            return result
        }
        pendingByShiftID[shiftID] = (token, task)
        let result = await task.value
        if pendingByShiftID[shiftID]?.token == token {
            pendingByShiftID[shiftID] = nil
        }
        return result
    }

    func reconcile(shifts: [Shift], now: Date = .now) async {
        let savedByID = Dictionary(shifts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for activity in Activity<BreakActivityAttributes>.activities {
            guard let shift = savedByID[activity.attributes.shiftID], shift.endsAt > now else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
        }

        resultsByShiftID = resultsByShiftID.filter { savedByID[$0.key] != nil }
        for shift in shifts {
            _ = await scheduleOrUpdate(shift: shift, now: now)
        }
    }

    func endActivities(forShiftIDs shiftIDs: [UUID]) async {
        for shiftID in shiftIDs {
            let previous = pendingByShiftID[shiftID]?.task
            let token = UUID()
            let task = Task { @MainActor in
                _ = await previous?.value
                for activity in Activity<BreakActivityAttributes>.activities
                where activity.attributes.shiftID == shiftID {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                resultsByShiftID[shiftID] = nil
                return ActivitySchedulingResult.alreadyEnded
            }
            pendingByShiftID[shiftID] = (token, task)
            _ = await task.value
            if pendingByShiftID[shiftID]?.token == token {
                pendingByShiftID[shiftID] = nil
            }
        }
    }

    private func scheduleOrUpdateActivity(shift: Shift, now: Date) async -> ActivitySchedulingResult {
        let matching = Activity<BreakActivityAttributes>.activities.filter { $0.attributes.shiftID == shift.id }
        guard shift.endsAt > now else {
            for activity in matching { await activity.end(nil, dismissalPolicy: .immediate) }
            return .alreadyEnded
        }

        guard let employee = shift.employee else {
            for activity in matching { await activity.end(nil, dismissalPolicy: .immediate) }
            return .failed("This shift has no employee.")
        }
        let interval = ShiftInterval(startsAt: shift.startsAt, endsAt: shift.endsAt)
        let countdownState = ShiftCountdown.state(for: interval, now: now)
        guard let content = content(for: countdownState, shift: shift) else { return .alreadyEnded }
        let attributes = BreakActivityAttributes(
            employeeID: employee.id,
            shiftID: shift.id,
            employeeName: employee.name,
            shiftStartsAt: shift.startsAt,
            shiftEndsAt: shift.endsAt
        )

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            for activity in matching { await activity.end(nil, dismissalPolicy: .immediate) }
            return .disabled
        }

        // Attributes cannot be changed after a request. Replace an edited shift's activity.
        let reusable = matching.first { activity in
            activity.attributes.employeeID == attributes.employeeID &&
            activity.attributes.employeeName == attributes.employeeName &&
            activity.attributes.shiftStartsAt == attributes.shiftStartsAt &&
            activity.attributes.shiftEndsAt == attributes.shiftEndsAt &&
            activity.activityState != .ended && activity.activityState != .dismissed
        }
        for activity in matching where activity.id != reusable?.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if let reusable {
            await reusable.update(content)
            return .updated
        }

        do {
            if shift.startsAt > now {
                if #available(iOS 26.0, *) {
                    let alert = AlertConfiguration(
                        title: "Break Planner",
                        body: "\(employee.name)'s shift is starting.",
                        sound: .default
                    )
                    _ = try Activity.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil,
                        style: .standard,
                        alertConfiguration: alert,
                        start: shift.startsAt
                    )
                } else {
                    return .waitingForShift
                }
            } else if #available(iOS 18.0, *) {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil, style: .standard)
            } else {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            }
            return .scheduled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func content(
        for state: ShiftCountdownState,
        shift: Shift
    ) -> ActivityContent<BreakActivityAttributes.ContentState>? {
        let event: BreakActivityAttributes.ContentState
        switch state {
        case .until(let stop, _):
            let kind = stop.kind == .rest ? "Rest break" : "Meal break"
            event = .init(eventTitle: "\(stop.letter) · \(kind)", eventLetter: stop.letter,
                          eventKind: stop.kind == .rest ? "rest" : "meal",
                          eventStartsAt: stop.startsAt, eventEndsAt: stop.endsAt)
        case .active(let stop, _):
            let kind = stop.kind == .rest ? "Rest break" : "Meal break"
            event = .init(eventTitle: "\(stop.letter) · \(kind) active", eventLetter: stop.letter,
                          eventKind: "activeBreak", eventStartsAt: stop.startsAt, eventEndsAt: stop.endsAt)
        case .noMoreStops(let shiftEnd, _):
            event = .init(eventTitle: "No more stops", eventLetter: nil, eventKind: "shiftEnd",
                          eventStartsAt: shiftEnd, eventEndsAt: shiftEnd)
        case .unsupportedDuration:
            event = .init(eventTitle: "No automatic route available", eventLetter: nil,
                          eventKind: "shiftEnd", eventStartsAt: shift.endsAt, eventEndsAt: shift.endsAt)
        case .complete:
            return nil
        }
        let target = event.eventKind == "activeBreak" ? event.eventEndsAt : event.eventStartsAt
        return ActivityContent(state: event, staleDate: target)
    }
}
