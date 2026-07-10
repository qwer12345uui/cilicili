import SwiftUI
import UIKit

struct PlaybackDetailFullscreenGeometry {
    let size: CGSize
    let offset: CGSize
}

extension GeometryProxy {
    func playbackDetailFullscreenGeometry(
        window: UIWindow?,
        resolveSize: (_ window: UIWindow, _ rootView: UIView) -> CGSize
    ) -> PlaybackDetailFullscreenGeometry {
        if let window,
           let rootView = window.rootViewController?.view {
            let localFrame = frame(in: .global)
            let frameInWindow = rootView.convert(localFrame, from: nil)
            return PlaybackDetailFullscreenGeometry(
                size: resolveSize(window, rootView),
                offset: CGSize(width: -frameInWindow.minX, height: -frameInWindow.minY)
            )
        }

        let expandedSize = CGSize(
            width: size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
            height: size.height + safeAreaInsets.top + safeAreaInsets.bottom
        )
        return PlaybackDetailFullscreenGeometry(
            size: expandedSize,
            offset: CGSize(width: -safeAreaInsets.leading, height: -safeAreaInsets.top)
        )
    }
}
