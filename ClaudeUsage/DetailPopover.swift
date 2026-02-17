import SwiftUI

struct DetailPopover: View {
    @ObservedObject var usageService: UsageService

    // Claude.ai blue for progress bars
    private let claudeBlue = Color(red: 0.35, green: 0.52, blue: 0.85)
    private let barBg = Color(red: 0.90, green: 0.91, blue: 0.93)
    private let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plan usage limits header
            Text("Plan usage limits")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textPrimary)
                .padding(.bottom, 16)

            // Error state
            if let error = usageService.usage.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }
                .padding(.bottom, 12)
            }

            // Current session section
            VStack(alignment: .leading, spacing: 4) {
                Text("Current session")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(sessionResetLabel)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)

                HStack(spacing: 12) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barBg)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(claudeBlue)
                                .frame(width: max(0, geo.size.width * min(usageService.usage.sessionPercent, 100) / 100))
                        }
                    }
                    .frame(height: 10)

                    Text("\(Int(round(usageService.usage.sessionPercent)))% used")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
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
                    .foregroundColor(textPrimary)

                Text("All models")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .padding(.top, 4)

                Text(weeklyResetLabel)
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary)

                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barBg)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(claudeBlue)
                                .frame(width: max(0, geo.size.width * min(usageService.usage.weeklyPercent, 100) / 100))
                        }
                    }
                    .frame(height: 10)

                    Text("\(Int(round(usageService.usage.weeklyPercent)))% used")
                        .font(.system(size: 13))
                        .foregroundColor(textSecondary)
                        .fixedSize()
                }
                .padding(.top, 4)
            }

            Divider()
                .padding(.vertical, 14)

            // Footer
            HStack {
                if let lastFetched = usageService.usage.lastFetched {
                    Text("Last updated: \(lastFetched, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                }

                Spacer()

                Button(action: { usageService.refreshNow() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
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
                    .foregroundColor(textSecondary)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return "Resets \(formatter.string(from: resetTime))"
    }
}
