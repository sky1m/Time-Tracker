import Foundation

enum ShiftCountdownState: Equatable {
    case until(stop: BreakStop, secondsRemaining: Int)
    case active(stop: BreakStop, secondsRemaining: Int)
    case noMoreStops(shiftEnd: Date, secondsRemaining: Int)
    case complete
    case unsupportedDuration
}

enum ShiftCountdown {
    static func state(for shift: ShiftInterval, now: Date) -> ShiftCountdownState {
        guard now < shift.endsAt else { return .complete }
        guard shift.endsAt.timeIntervalSince(shift.startsAt) <= 14 * 60 * 60 else {
            return .unsupportedDuration
        }

        let stops = BreakScheduleCalculator.stops(for: shift)
        if let active = stops.first(where: { $0.startsAt <= now && now < $0.endsAt }) {
            return .active(stop: active, secondsRemaining: seconds(until: active.endsAt, from: now))
        }
        if let next = stops.first(where: { now < $0.startsAt }) {
            return .until(stop: next, secondsRemaining: seconds(until: next.startsAt, from: now))
        }
        return .noMoreStops(
            shiftEnd: shift.endsAt,
            secondsRemaining: seconds(until: shift.endsAt, from: now)
        )
    }

    private static func seconds(until date: Date, from now: Date) -> Int {
        // Round up so a future boundary never displays a premature zero.
        Int(ceil(max(0, date.timeIntervalSince(now))))
    }
}
