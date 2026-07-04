import SwiftUI
import UIKit

struct VideoDetailInitialPlaybackLayout {
    let width: CGFloat
    let playerHeight: CGFloat

    init(proxy: GeometryProxy, isPortraitVideo: Bool) {
        let fullscreenSize = proxy.fullscreenContainerGeometry.size
        width = VideoDetailStablePortraitLayout.width(
            proxySize: proxy.size,
            fullscreenSize: fullscreenSize
        )

        let standardHeight = width * 9 / 16
        if isPortraitVideo {
            let proposedHeight = max(proxy.size.height * 0.65, width)
            let maximumHeight = max(standardHeight, proxy.size.height * 0.72)
            playerHeight = max(standardHeight, min(proposedHeight, maximumHeight))
        } else {
            playerHeight = standardHeight
        }
    }
}

enum VideoDetailStablePortraitLayout {
    static func width(proxySize: CGSize, fullscreenSize: CGSize) -> CGFloat {
        let proxyShortSide = min(proxySize.width, proxySize.height)
        let fullscreenShortSide = min(fullscreenSize.width, fullscreenSize.height)
        let windowShortSide = UIApplication.shared.biliForegroundKeyWindow.map { window in
            min(window.bounds.width, window.bounds.height)
        } ?? .greatestFiniteMagnitude
        return min(proxyShortSide, fullscreenShortSide, windowShortSide)
    }
}
