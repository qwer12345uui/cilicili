import SwiftUI

struct PlaybackDetailLoadedStatePage<Value, LoadedContent: View, InitialContent: View>: View {
    let value: Value?
    let loadedContent: (Value) -> LoadedContent
    let initialContent: () -> InitialContent
    @State private var keepsInitialContent = true

    init(
        _ value: Value?,
        @ViewBuilder loadedContent: @escaping (Value) -> LoadedContent,
        @ViewBuilder initialContent: @escaping () -> InitialContent
    ) {
        self.value = value
        self.loadedContent = loadedContent
        self.initialContent = initialContent
    }

    var body: some View {
        ZStack {
            if keepsInitialContent {
                initialContent()
                    .opacity(isLoaded ? 0 : 1)
                    .allowsHitTesting(!isLoaded)
                    .accessibilityHidden(isLoaded)
            }

            if let value {
                loadedContent(value)
                    .zIndex(1)
            }
        }
        .task(id: isLoaded) {
            guard isLoaded else {
                keepsInitialContent = true
                return
            }
            await Task.yield()
            keepsInitialContent = false
        }
    }

    private var isLoaded: Bool {
        value != nil
    }
}
