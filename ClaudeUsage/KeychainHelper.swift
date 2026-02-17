import Foundation

struct OAuthCredentials {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date?
}

enum KeychainHelper {
    /// Cached token to avoid repeated keychain reads
    private static var cachedCredentials: OAuthCredentials?
    private static var cacheTime: Date?

    static func readClaudeOAuthToken() -> OAuthCredentials? {
        // Return cached token if less than 5 minutes old
        if let cached = cachedCredentials, let cacheTime = cacheTime,
           Date().timeIntervalSince(cacheTime) < 300 {
            return cached
        }

        // Use the `security` CLI tool — this avoids the GUI password prompt
        // because the terminal/shell already has keychain access granted
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // suppress stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to run security command: \(error)")
            return nil
        }

        guard process.terminationStatus == 0 else {
            print("security command failed with status \(process.terminationStatus)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let rawString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawString.isEmpty else {
            print("Empty keychain data")
            return nil
        }

        guard let jsonData = rawString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("Failed to parse keychain JSON")
            return nil
        }

        let credentials = extractCredentials(from: json)
        cachedCredentials = credentials
        cacheTime = Date()
        return credentials
    }

    /// Clear cached credentials (call when token is expired)
    static func clearCache() {
        cachedCredentials = nil
        cacheTime = nil
    }

    private static func extractCredentials(from json: [String: Any]) -> OAuthCredentials? {
        // The keychain entry has a claudeAiOauth object
        guard let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String else {
            print("Missing claudeAiOauth.accessToken in keychain data")
            return nil
        }

        let refreshToken = oauth["refreshToken"] as? String ?? ""
        var expiresAt: Date? = nil
        if let expiresAtStr = oauth["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresAtStr)
        } else if let expiresAtNum = oauth["expiresAt"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: expiresAtNum / 1000)
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }
}
