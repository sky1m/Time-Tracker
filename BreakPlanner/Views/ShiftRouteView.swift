import SwiftUI

struct ShiftRouteView: View {
    let shift: Shift
    @Environment(\.scenePhase) private var scenePhase
    @State private var timelineStart = Date.now

    private var interval: ShiftInterval {
        ShiftInterval(startsAt: shift.startsAt, endsAt: shift.endsAt)
    }

    var body: some View {
        let stops = BreakScheduleCalculator.stops(for: interval)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.employee?.name ?? "Shift route").font(.title2.bold())
                    Text(WorkdayDate.localDate(fromStored: shift.workday),
                         format: Date.FormatStyle(calendar: WorkdayDate.localCalendar).weekday().month().day().year())
                        .foregroundStyle(TransitTheme.secondaryText)
                    Text("\(shift.startsAt.formatted(date: .omitted, time: .shortened)) – \(shift.endsAt.formatted(date: .omitted, time: .shortened))")
                    if !Calendar.current.isDate(shift.startsAt, inSameDayAs: shift.endsAt) {
                        Text("Ends the following day").font(.caption).foregroundStyle(TransitTheme.secondaryText)
                    }
                }

                TimelineView(.periodic(from: timelineStart, by: 1)) { context in
                    ShiftCountdownSummary(state: ShiftCountdown.state(for: interval, now: context.date))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TransitTheme.surface, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 0) {
                    routeStop(letter: "A", title: "Shift start", date: shift.startsAt, duration: nil, route: .shift, connects: !stops.isEmpty)
                    ForEach(Array(stops.enumerated()), id: \.element.letter) { index, stop in
                        routeStop(
                            letter: stop.letter,
                            title: stop.kind == .rest ? "Rest break" : "Meal break",
                            date: stop.startsAt,
                            duration: stop.durationMinutes,
                            route: stop.kind == .rest ? .rest : .meal,
                            connects: index < stops.count - 1
                        )
                    }
                }
                Text("Shift ends \(shift.endsAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(TransitTheme.secondaryText)
            }
            .padding()
        }
        .transitScreenStyle()
        .navigationTitle("Shift Route")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { timelineStart = .now }
        }
    }

    private func routeStop(letter: String, title: String, date: Date, duration: Int?, route: TransitTheme.Route, connects: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            TransitStopBadge(letter: letter, route: route)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(date, format: .dateTime.hour().minute())
                if !Calendar.current.isDate(date, inSameDayAs: shift.startsAt) {
                    Text(date, format: .dateTime.month().day()).font(.caption).foregroundStyle(TransitTheme.secondaryText)
                }
                if let duration {
                    Text("\(duration) minutes").font(.caption).foregroundStyle(TransitTheme.secondaryText)
                }
            }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            if connects {
                Rectangle()
                    .fill(route.color)
                    .frame(width: 6)
                    .padding(.leading, 17)
                    .padding(.top, 20)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ShiftCountdownSummary: View {
    let state: ShiftCountdownState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch state {
            case .until(let stop, let seconds):
                Text("Time til next stop").font(.headline)
                countdown(seconds)
                Text("\(stop.letter) · \(kindLabel(stop)) at \(stop.startsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(TransitTheme.secondaryText)
            case .active(let stop, let seconds):
                Text("\(stop.letter) · \(kindLabel(stop)) active").font(.headline)
                countdown(seconds)
                Text("Time remaining in break · Ends at \(stop.endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(TransitTheme.secondaryText)
            case .noMoreStops(let shiftEnd, let seconds):
                Text("No more stops").font(.headline)
                countdown(seconds)
                Text("Time til shift end · \(shiftEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(TransitTheme.secondaryText)
            case .complete:
                Text("Shift complete").font(.headline)
            case .unsupportedDuration:
                Text("No automatic route available").font(.headline)
                Text("Automatic break routes support shifts up to 14 hours.")
                    .font(.caption).foregroundStyle(TransitTheme.secondaryText)
            }
        }
        .foregroundStyle(TransitTheme.text)
    }

    private func countdown(_ seconds: Int) -> some View {
        Text(String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60))
            .font(.title3.monospacedDigit())
            .accessibilityLabel("\(seconds / 3600) hours, \((seconds % 3600) / 60) minutes, \(seconds % 60) seconds remaining")
    }

    private func kindLabel(_ stop: BreakStop) -> String {
        stop.kind == .rest ? "Rest break" : "Meal break"
    }
}
