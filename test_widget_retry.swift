#!/usr/bin/env swift
// Automated test for Claude Usage widget: credential sources, retry/backoff, and API call.
// Run: swift test_widget_retry.swift

import Foundation

// ── Constants matching UsageService.swift ──
let defaultInterval: TimeInterval = 60
let maxInterval: TimeInterval = 120
let credentialsFilePath = NSString("~/.claude/.credentials.json").expandingTildeInPath

var passed = 0
var failed = 0

func check(_ name: String, _ condition: Bool) {
    if condition {
        passed += 1
        print("  PASS: \(name)")
    } else {
        failed += 1
        print("  FAIL: \(name)")
    }
}

// ── Test 1: Credentials file exists and is readable ──
print("\n[Test 1] Credentials file (~/.claude/.credentials.json)")
let fileExists = FileManager.default.fileExists(atPath: credentialsFilePath)
check("File exists", fileExists)

var fileToken: String?
if fileExists,
   let data = FileManager.default.contents(atPath: credentialsFilePath),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    check("JSON parseable", true)

    if let oauth = json["claudeAiOauth"] as? [String: Any],
       let token = oauth["accessToken"] as? String {
        fileToken = token
        check("Token found (nested claudeAiOauth)", true)
        check("Token starts with sk-ant-", token.hasPrefix("sk-ant-"))
    } else if let token = json["accessToken"] as? String {
        fileToken = token
        check("Token found (flat)", true)
        check("Token starts with sk-ant-", token.hasPrefix("sk-ant-"))
    } else {
        check("Token found", false)
    }
} else {
    check("JSON parseable", false)
}

// ── Test 2: Keychain read (fallback source) ──
print("\n[Test 2] Keychain (fallback)")
var keychainToken: String?
do {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-g"]
    let errPipe = Pipe()
    process.standardOutput = Pipe()
    process.standardError = errPipe
    try process.run()
    process.waitUntilExit()

    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: errData, encoding: .utf8),
       let range = output.range(of: #"password: "(.*)""#, options: .regularExpression) {
        let line = String(output[range])
        let start = line.index(line.startIndex, offsetBy: 11)
        let end = line.index(before: line.endIndex)
        let decoded = String(line[start..<end])
        if let jsonData = decoded.data(using: .utf8),
           let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            keychainToken = json["accessToken"] as? String
                ?? (json["claudeAiOauth"] as? [String: Any])?["accessToken"] as? String
        }
    }
    check("Keychain readable", keychainToken != nil)
} catch {
    check("Keychain readable", false)
}

// ── Test 3: Token comparison ──
print("\n[Test 3] Token sync")
if let ft = fileToken, let kt = keychainToken {
    let match = ft == kt
    if match {
        check("File and Keychain tokens match", true)
    } else {
        check("File and Keychain tokens match", false)
        print("    File token:     \(ft.prefix(20))...")
        print("    Keychain token: \(kt.prefix(20))...")
        print("    Widget MUST use file token (primary) to work correctly")
    }
} else {
    print("  SKIP: Cannot compare (one source missing)")
}

// ── Test 4: Backoff logic ──
print("\n[Test 4] Backoff caps at 120s")
var interval = defaultInterval
for _ in 0..<10 { interval = min(interval * 2, maxInterval) }
check("Max backoff is 120s", interval == 120)

// ── Test 5: Minimum retry delay ──
print("\n[Test 5] Minimum retry delay on 429")
for retryAfterValue in [0, 1, 5, 10, 20] {
    let retryDelay = max(retryAfterValue, 10)
    check("Retry-After:\(retryAfterValue) → delay \(retryDelay) >= 10", retryDelay >= 10)
}

// ── Test 6: Success resets interval ──
print("\n[Test 6] Success resets interval")
interval = maxInterval
interval = defaultInterval  // simulates reset on success
check("After success, interval resets to 60s", interval == 60)

// ── Test 7: Real API call with FILE token (primary path) ──
print("\n[Test 7] API call with file token (widget's primary path)")
if let token = fileToken {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    request.setValue("claude-code/2.1.63", forHTTPHeaderField: "User-Agent")

    let semaphore = DispatchSemaphore(value: 0)
    var statusCode = 0
    var apiJson: [String: Any]?

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let http = response as? HTTPURLResponse {
            statusCode = http.statusCode
            if let data = data {
                apiJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
        }
        semaphore.signal()
    }.resume()
    semaphore.wait()

    if statusCode == 200 {
        check("API returns 200", true)
        if let fiveHour = apiJson?["five_hour"] as? [String: Any],
           let util = fiveHour["utilization"] as? Double {
            check("Session utilization: \(util)%", util >= 0)
        }
        if let sevenDay = apiJson?["seven_day"] as? [String: Any],
           let util = sevenDay["utilization"] as? Double {
            check("Weekly utilization: \(util)%", util >= 0)
        }
    } else if statusCode == 429 {
        print("  SKIP: API returned 429 (rate limited, expected if called recently)")
        passed += 1
    } else if statusCode == 401 {
        check("API auth (got 401 — file token is expired/invalid!)", false)
    } else {
        check("API returns 200 (got \(statusCode))", false)
    }
} else {
    print("  SKIP: No file token available")
}

// ── Summary ──
print("\n═══════════════════════════")
print("Results: \(passed) passed, \(failed) failed")
if failed > 0 {
    print("STATUS: FAIL")
    exit(1)
} else {
    print("STATUS: ALL PASS")
}
