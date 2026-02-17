import AppKit
import SwiftUI

enum MenuBarRenderer {
    // Retro-digital colors
    static let orangeColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    static let dimOrangeColor = NSColor(red: 0.30, green: 0.18, blue: 0.02, alpha: 1.0)
    static let backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0)

    // Cache the logo image (SPM puts resources in Bundle.module)
    private static let logoImage: NSImage? = {
        // Try Bundle.module first (SPM resource bundle)
        if let url = Bundle.module.url(forResource: "claude-logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Fallback: check main bundle Resources folder (for .app bundle)
        if let url = Bundle.main.url(forResource: "claude-logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Fallback: check alongside the executable
        let execURL = Bundle.main.executableURL?.deletingLastPathComponent()
        if let resURL = execURL?.deletingLastPathComponent().appendingPathComponent("Resources/claude-logo.png"),
           let img = NSImage(contentsOf: resURL) {
            return img
        }
        return nil
    }()

    static func renderMenuBarImage(percentage: Double) -> NSImage {
        let height: CGFloat = 22

        // Pre-calculate percentage text width
        let pctNumber = "\(Int(round(percentage)))"
        let numFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .heavy)
        let pctSymFont = NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .bold)
        let numSize = (pctNumber as NSString).size(withAttributes: [.font: numFont])
        let pctSymSize = ("%" as NSString).size(withAttributes: [.font: pctSymFont])
        let pctTotalWidth = numSize.width + pctSymSize.width + 1

        // Layout constants
        let leftPad: CGFloat = 5
        let logoDrawSize: CGFloat = 16
        let logoRightMargin: CGFloat = 4
        let barSegments = 18
        let segW: CGFloat = 4.0
        let segGap: CGFloat = 1.8
        let barRightMargin: CGFloat = 5
        let rightPad: CGFloat = 5

        let barTotalWidth = CGFloat(barSegments) * segW + CGFloat(barSegments - 1) * segGap
        let totalWidth = leftPad + logoDrawSize + logoRightMargin + barTotalWidth + barRightMargin + pctTotalWidth + rightPad

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flippable: false) { _ in
            let rect = NSRect(x: 0, y: 0, width: totalWidth, height: height)

            // Enable anti-aliasing
            NSGraphicsContext.current?.shouldAntialias = true
            NSGraphicsContext.current?.imageInterpolation = .high

            // Black rounded pill background
            let bgRect = rect.insetBy(dx: 0.5, dy: 1.5)
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 5, yRadius: 5)
            backgroundColor.setFill()
            bgPath.fill()

            // Subtle border
            NSColor(white: 0.2, alpha: 0.5).setStroke()
            bgPath.lineWidth = 0.5
            bgPath.stroke()

            var x: CGFloat = leftPad

            // Draw the actual Claude logo PNG
            if let logo = logoImage {
                let logoRect = NSRect(
                    x: x,
                    y: (height - logoDrawSize) / 2,
                    width: logoDrawSize,
                    height: logoDrawSize
                )
                logo.draw(in: logoRect,
                          from: NSRect(origin: .zero, size: logo.size),
                          operation: .sourceOver,
                          fraction: 1.0)
            }
            x += logoDrawSize + logoRightMargin

            // Progress bar segments
            let segH: CGFloat = 12
            let segY: CGFloat = (height - segH) / 2
            let filledCount = Int(round(percentage / 100.0 * Double(barSegments)))

            for i in 0..<barSegments {
                let segRect = NSRect(x: x, y: segY, width: segW, height: segH)
                let color = i < filledCount ? orangeColor : dimOrangeColor
                color.setFill()
                NSBezierPath(roundedRect: segRect, xRadius: 0.8, yRadius: 0.8).fill()
                x += segW + segGap
            }

            x += barRightMargin - segGap

            // Percentage: number in large font, "%" in smaller font
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: numFont,
                .foregroundColor: orangeColor
            ]
            let symAttrs: [NSAttributedString.Key: Any] = [
                .font: pctSymFont,
                .foregroundColor: orangeColor
            ]

            let numY = (height - numSize.height) / 2
            (pctNumber as NSString).draw(at: NSPoint(x: x, y: numY), withAttributes: numAttrs)
            x += numSize.width + 1
            let symY = numY + (numSize.height - pctSymSize.height) / 2 + 1
            ("%" as NSString).draw(at: NSPoint(x: x, y: symY), withAttributes: symAttrs)
        }

        return image
    }
}

// Helper to create NSImage with drawing closure
extension NSImage {
    convenience init(size: NSSize, flippable: Bool, drawingHandler: @escaping (NSGraphicsContext?) -> Void) {
        self.init(size: size)
        self.lockFocus()
        let ctx = NSGraphicsContext.current
        drawingHandler(ctx)
        self.unlockFocus()
    }
}
