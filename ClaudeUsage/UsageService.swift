import Foundation
import Combine

struct UsageData {
    var sessionPercent: Double = 0
    var sessionResetTime: Date? = nil
    var weeklyPercent: Double = 0
    var weeklyResetTime: Date? = nil
    var lastFetched: Date? = nil
    var error: String? = nil
}

@MainActor
class UsageService: ObservableObject {
    @Published var usage = UsageData()
    @Published var isLoading = false

    private var timer: Timer?
    private var refreshInterval: TimeInterval = 60

    init() {
        startPolling()
    }

    func startPolling() {
        timer?.invalidate()
        Task { await fetchUsage() }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchUsage()
            }
        }
    }

    func refreshNow() {
        Task { await fetchUsage() }
    }

    func fetchUsage() async {
        guard let credentials = KeychainHelper.readClaudeOAuthToken() else {
            usage.error = "No OAuth token found. Make sure you're logged into Claude Code."
            return
        }

        // Check if token is expired
        if let expiresAt = credentials.expiresAt, expiresAt < Date() {
            KeychainHelper.clearCache()
            usage.error = "OAuth token expired. Run 'claude' to refresh your session."
            return
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                usage.error = "Invalid response"
                return
            }

            // Log raw response for debugging
            if let rawStr = String(data: data, encoding: .utf8) {
                print("[ClaudeUsage] API response (\(httpResponse.statusCode)): \(rawStr)")
            }

            if httpResponse.statusCode == 401 {
                KeychainHelper.clearCache()
                usage.error = "Token expired. Run 'claude' to refresh your session."
                return
            }

            guard httpResponse.statusCode == 200 else {
                usage.error = "API error: HTTP \(httpResponse.statusCode)"
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                usage.error = "Failed to parse response"
                return
            }

            parseUsageResponse(json)
            usage.lastFetched = Date()
            usage.error = nil

        } catch {
            usage.error = "Network error: \(error.localizedDescription)"
        }
    }

    private func parseUsageResponse(_ json: [String: Any]) {
        // Parse five_hour (current session)
        if let fiveHour = json["five_hour"] as? [String: Any] {
            if let utilization = fiveHour["utilization"] as? Double {
                usage.sessionPercent = utilization
            }
            if let resetAt = fiveHour["resets_at"] as? String {
                usage.sessionResetTime = parseDate(resetAt)
            }
        }

        // Parse seven_day (weekly)
        if let sevenDay = json["seven_day"] as? [String: Any] {
            if let utilization = sevenDay["utilization"] as? Double {
                usage.weeklyPercent = utilization
            }
            if let resetAt = sevenDay["resets_at"] as? String {
                usage.weeklyResetTime = parseDate(resetAt)
            }
        }
    }

    private func parseDate(_ string: String) -> Date? {
        // Try ISO8601DateFormatter with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }

        // Fallback without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        // Fallback: DateFormatter which handles more formats
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSxxx"
        if let date = df.date(from: string) { return date }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx"
        return df.date(from: string)
    }

    deinit {
        timer?.invalidate()
    }
}
