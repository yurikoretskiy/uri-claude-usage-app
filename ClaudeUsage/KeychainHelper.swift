import Foundation

private extension Data {
    init?(hexString: String) {
        let len = hexString.count
        guard len % 2 == 0 else { return nil }
        var data = Data(capacity: len / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

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

        // Use `security -g` which outputs the full hex password on stderr.
        // The `-w` flag truncates large passwords (~2010 bytes), breaking
        // JSON parsing when credentials are hex-encoded.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-g"]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

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

        // `-g` outputs the password on stderr
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: errData, encoding: .utf8), !output.isEmpty else {
            print("Empty keychain data")
            return nil
        }

        let decoded = decodeKeychainOutput(output)
        guard let decoded = decoded, !decoded.isEmpty else {
            print("Could not decode keychain password")
            return nil
        }

        // Try full JSON parse first (works if data isn't truncated)
        if let jsonData = decoded.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let credentials = extractCredentials(from: json)
            cachedCredentials = credentials
            cacheTime = Date()
            return credentials
        }

        // Fallback: extract token via regex (handles truncated JSON)
        let credentials = extractCredentialsViaRegex(from: decoded)
        cachedCredentials = credentials
        cacheTime = Date()
        return credentials
    }

    /// Decode the password line from `security -g` output.
    /// Format is either `password: 0x<HEX><trailing>` or `password: "<string>"`.
    private static func decodeKeychainOutput(_ output: String) -> String? {
        // Hex-encoded password (newer macOS / Claude Code versions)
        if let match = output.range(of: #"password: 0x([0-9A-Fa-f]+)(.*)"#, options: .regularExpression) {
            let line = String(output[match])
            // Extract hex portion
            if let hexRange = line.range(of: #"0x([0-9A-Fa-f]+)"#, options: .regularExpression) {
                let hexWithPrefix = String(line[hexRange])
                let hex = String(hexWithPrefix.dropFirst(2))
                guard let data = Data(hexString: hex),
                      let decoded = String(data: data, encoding: .utf8) else { return nil }
                // Append any trailing text after the hex (security CLI may include it)
                let afterHex = String(line[hexRange.upperBound...])
                return decoded + afterHex
            }
        }
        // Plain string password
        if let match = output.range(of: #"password: "(.*)""#, options: .regularExpression) {
            let line = String(output[match])
            let start = line.index(line.startIndex, offsetBy: 11) // skip `password: "`
            let end = line.index(before: line.endIndex)            // skip trailing `"`
            return String(line[start..<end])
        }
        return nil
    }

    /// Extract credentials via regex when JSON is truncated.
    private static func extractCredentialsViaRegex(from text: String) -> OAuthCredentials? {
        guard let tokenMatch = text.range(of: #""accessToken"\s*:\s*"(sk-ant-[^"]+)""#, options: .regularExpression) else {
            print("Missing accessToken in keychain data")
            return nil
        }
        // Extract the token value from the match
        let matchStr = String(text[tokenMatch])
        guard let valueStart = matchStr.range(of: "sk-ant-"),
              let valueEnd = matchStr.lastIndex(of: "\"") else { return nil }
        let accessToken = String(matchStr[valueStart.lowerBound..<valueEnd])

        // Try to extract refreshToken
        var refreshToken = ""
        if let rtMatch = text.range(of: #""refreshToken"\s*:\s*"(sk-ant-[^"]+)""#, options: .regularExpression) {
            let rtStr = String(text[rtMatch])
            if let rtStart = rtStr.range(of: "sk-ant-"),
               let rtEnd = rtStr.lastIndex(of: "\"") {
                refreshToken = String(rtStr[rtStart.lowerBound..<rtEnd])
            }
        }

        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAt: nil)
    }

    /// Clear cached credentials (call when token is expired)
    static func clearCache() {
        cachedCredentials = nil
        cacheTime = nil
    }

    private static func extractCredentials(from json: [String: Any]) -> OAuthCredentials? {
        // Try nested format first (legacy): {"claudeAiOauth": {"accessToken": ...}}
        if let oauth = json["claudeAiOauth"] as? [String: Any],
           let accessToken = oauth["accessToken"] as? String {
            return parseOAuthFields(from: oauth, accessToken: accessToken)
        }

        // Flat format (current): {"accessToken": "sk-ant-..."}
        if let accessToken = json["accessToken"] as? String {
            return parseOAuthFields(from: json, accessToken: accessToken)
        }

        print("Missing accessToken in keychain data")
        return nil
    }

    private static func parseOAuthFields(from dict: [String: Any], accessToken: String) -> OAuthCredentials {
        let refreshToken = dict["refreshToken"] as? String ?? ""
        var expiresAt: Date? = nil
        if let expiresAtStr = dict["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresAtStr)
        } else if let expiresAtNum = dict["expiresAt"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: expiresAtNum / 1000)
        }
        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}
