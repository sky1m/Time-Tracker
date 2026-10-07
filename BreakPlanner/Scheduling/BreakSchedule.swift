import Foundation

struct ShiftInterval: Equatable {
    let startsAt: Date
    let endsAt: Date
}

enum BreakKind: Equatable {
    case rest
    case meal
}

struct BreakStop: Equatable {
    let letter: String
    let kind: BreakKind
    let startsAt: Date
    let durationMinutes: Int

    var endsAt: Date {
        startsAt.addingTimeInterval(TimeInterval(durationMinutes) * 60)
    }
}

enum BreakScheduleCalculator {
    static func stops(for shift: ShiftInterval) -> [BreakStop] {
        let duration = shift.endsAt.timeIntervalSince(shift.startsAt)
        let hour: TimeInterval = 60 * 60
        guard duration.isFinite, duration > 0, duration <= 14 * hour else {
            return []
        }

        let kinds: [BreakKind]
        switch duration {
        case ...(5 * hour):
            kinds = [.rest]
        case ...(6 * hour):
            kinds = [.meal, .rest]
        case ...(10 * hour):
            kinds = [.rest, .meal, .rest]
        default:
            kinds = [.rest, .meal, .rest, .meal, .rest]
        }

        let letters = ["B", "C", "D", "E", "F"]
        return kinds.enumerated().compactMap { index, kind in
            // Offsets are elapsed hours from the absolute shift start, including overnight shifts.
            let startsAt = shift.startsAt.addingTimeInterval(TimeInterval(index + 1) * 2 * hour)
            guard startsAt < shift.endsAt else { return nil }
            return BreakStop(
                letter: letters[index],
                kind: kind,
                startsAt: startsAt,
                durationMinutes: kind == .rest ? 15 : 30
            )
        }
    }
}
