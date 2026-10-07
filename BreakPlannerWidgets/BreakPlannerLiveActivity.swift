import ActivityKit
import SwiftUI
import WidgetKit

struct BreakPlannerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreakActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.07, green: 0.12, blue: 0.18))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    stopMarker(context.state.eventLetter, color: routeColor(for: context.state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: countdownTarget(for: context.state))
                        .font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.eventTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(eventClockDescription(for: context.state))
                            .font(.caption)
                        Text(context.attributes.employeeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        shiftRange(context.attributes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                stopMarker(context.state.eventLetter, color: routeColor(for: context.state))
                    .font(.caption.bold())
            } compactTrailing: {
                countdown(to: countdownTarget(for: context.state))
                    .font(.caption.monospacedDigit())
            } minimal: {
                stopMarker(context.state.eventLetter, color: routeColor(for: context.state))
                    .font(.caption.bold())
            }
            .keylineTint(routeColor(for: context.state))
        }
    }

    private func lockScreenView(
        context: ActivityViewContext<BreakActivityAttributes>
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            stopMarker(context.state.eventLetter, color: routeColor(for: context.state))
                .font(.title3.bold())
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.eventTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(eventClockDescription(for: context.state))
                    .font(.subheadline.weight(.semibold))
                Text(context.attributes.employeeName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                shiftRange(context.attributes)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(countdownLabel(for: context.state))
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.7))
                countdown(to: countdownTarget(for: context.state))
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private func stopMarker(_ letter: String?, color: Color) -> some View {
        Text(letter ?? "•")
            .foregroundStyle(.white)
            .frame(minWidth: 24, minHeight: 24)
            .background(color, in: Circle())
            .accessibilityLabel(letter.map { "Stop \($0)" } ?? "Shift end")
    }

    private func countdown(to date: Date) -> some View {
        let now = Date.now
        let deadline = max(now, date)
        return Text(timerInterval: now...deadline, pauseTime: deadline, countsDown: true)
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
    }

    private func shiftRange(_ attributes: BreakActivityAttributes) -> some View {
        Text("Shift \(attributes.shiftStartsAt.formatted(date: .omitted, time: .shortened))–\(attributes.shiftEndsAt.formatted(date: .omitted, time: .shortened))")
    }

    private func countdownTarget(for state: BreakActivityAttributes.ContentState) -> Date {
        state.eventKind == "activeBreak" ? state.eventEndsAt : state.eventStartsAt
    }

    private func eventClockDescription(for state: BreakActivityAttributes.ContentState) -> String {
        let label: String
        switch state.eventKind {
        case "activeBreak": label = "Ends at"
        case "shiftEnd": label = "Shift ends at"
        default: label = "Starts at"
        }
        return "\(label) \(countdownTarget(for: state).formatted(date: .omitted, time: .shortened))"
    }

    private func countdownLabel(for state: BreakActivityAttributes.ContentState) -> String {
        switch state.eventKind {
        case "activeBreak": return "ENDS IN"
        case "shiftEnd": return "SHIFT ENDS IN"
        default: return "STARTS IN"
        }
    }

    private func routeColor(for state: BreakActivityAttributes.ContentState) -> Color {
        if state.eventKind == "activeBreak" { return .green }
        switch state.eventKind?.lowercased() {
        case "meal": return .orange
        case "rest": return .green
        default: return .blue
        }
    }
}
