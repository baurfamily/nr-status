import AppKit
import SwiftUI

struct InspectorWindowExpansion: NSViewRepresentable {
    let isPresented: Bool
    let inspectorWidth: CGFloat

    static func expandedFrame(
        from frame: NSRect, inspectorWidth: CGFloat, visibleFrame: NSRect, maxWidth: CGFloat
    ) -> NSRect {
        let growth = min(
            max(0, inspectorWidth),
            max(0, visibleFrame.maxX - frame.maxX),
            max(0, maxWidth - frame.width)
        )
        var result = frame
        result.size.width += growth
        return result
    }

    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.update(isPresented: isPresented, inspectorWidth: inspectorWidth)
    }

    final class AnchorView: NSView {
        private var isPresented = false
        private var inspectorWidth: CGFloat = 0
        private weak var expandedWindow: NSWindow?
        private var addedWidth: CGFloat = 0
        private var expectedWidth: CGFloat = 0
        private var userResized = false
        private var isApplying = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func update(isPresented: Bool, inspectorWidth: CGFloat) {
            self.isPresented = isPresented
            self.inspectorWidth = inspectorWidth
            apply()
        }

        private func apply() {
            guard !isApplying else { return }
            isApplying = true
            defer { isApplying = false }
            guard let window else { return }
            if isPresented {
                guard !window.styleMask.contains(.fullScreen),
                      let screen = window.screen ?? NSScreen.main else { return }
                if expandedWindow !== window {
                    expandedWindow = window
                    addedWidth = 0
                    expectedWidth = window.frame.width
                    userResized = false
                }
                guard !userResized else { return }
                guard abs(window.frame.width - expectedWidth) < 1 else {
                    userResized = true
                    return
                }
                var base = window.frame
                base.size.width -= addedWidth
                let frame = InspectorWindowExpansion.expandedFrame(
                    from: base, inspectorWidth: inspectorWidth,
                    visibleFrame: screen.visibleFrame, maxWidth: window.maxSize.width
                )
                if abs(frame.width - window.frame.width) > 0.5 {
                    window.setFrame(frame, display: true)
                }
                addedWidth = window.frame.width - base.width
                expectedWidth = window.frame.width
            } else if expandedWindow === window {
                defer {
                    expandedWindow = nil
                    addedWidth = 0
                    userResized = false
                }
                // A manual resize while the inspector was open becomes the user's chosen window size.
                guard !userResized, addedWidth > 0, abs(window.frame.width - expectedWidth) < 1,
                      !window.styleMask.contains(.fullScreen) else { return }
                var frame = window.frame
                frame.size.width = max(window.minSize.width, frame.width - addedWidth)
                window.setFrame(frame, display: true)
            }
        }
    }
}
