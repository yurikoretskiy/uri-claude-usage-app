import SwiftUI

struct DetailPopover: View {
    @ObservedObject var usageService: UsageService

    // Orange accent for progress bars (matches menu bar widget)
    private let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plan usage limits header
            Text("Plan usage limits")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            // Error state
            if let error = usageService.usage.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)
            }

            // Current session section
            VStack(alignment: .leading, spacing: 4) {
                Text("Current session")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(sessionResetLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accentOrange)
                                .frame(width: max(0, geo.size.width * min(usageService.usage.sessionPercent, 100) / 100))
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(round(usageService.usage.sessionPercent)))% used")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
                .padding(.top, 4)
            }

            Divider()
                .padding(.vertical, 14)

            // Weekly limits section
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly limits")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Text("All models")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 4)

                Text(weeklyResetLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accentOrange)
                                .frame(width: max(0, geo.size.width * min(usageService.usage.weeklyPercent, 100) / 100))
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(round(usageService.usage.weeklyPercent)))% used")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
                .padding(.top, 4)

                // Model-specific limits (e.g. Sonnet, Opus)
                ForEach(Array(usageService.usage.modelLimits.enumerated()), id: \.offset) { _, model in
                    Text(model.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.top, 10)

                    if let resetTime = model.resetTime {
                        Text("Resets \(resetLabel(for: resetTime))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(accentOrange)
                                    .frame(width: max(0, geo.size.width * min(model.percent, 100) / 100))
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(round(model.percent)))% used")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                    .padding(.top, 4)
                }
            }

            Divider()
                .padding(.vertical, 14)

            // Footer
            HStack {
                if let lastFetched = usageService.usage.lastFetched {
                    Text("Last updated: \(lastFetched, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { usageService.refreshNow() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.vertical, 8)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 300)
    }

    private var sessionResetLabel: String {
        guard let resetTime = usageService.usage.sessionResetTime else {
            return ""
        }
        let remaining = resetTime.timeIntervalSinceNow
        if remaining <= 0 { return "Resetting soon" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours) hr \(minutes) min"
        }
        return "Resets in \(minutes) min"
    }

    private var weeklyResetLabel: String {
        guard let resetTime = usageService.usage.weeklyResetTime else {
            return ""
        }
        return resetLabel(for: resetTime)
    }

    private func resetLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}
