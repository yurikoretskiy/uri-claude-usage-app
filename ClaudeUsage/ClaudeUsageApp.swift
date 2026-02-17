import SwiftUI
import AppKit

@main
struct ClaudeUsageApp: App {
    @StateObject private var usageService = UsageService()

    var body: some Scene {
        MenuBarExtra {
            DetailPopover(usageService: usageService)
        } label: {
            Image(nsImage: MenuBarRenderer.renderMenuBarImage(
                percentage: usageService.usage.sessionPercent
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
