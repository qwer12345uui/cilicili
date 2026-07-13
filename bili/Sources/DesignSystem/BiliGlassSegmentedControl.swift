import SwiftUI

struct BiliGlassSegmentedControl<Option: Identifiable & Hashable>: View {
    @Environment(\.appThemeTintColor) private var appTintColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let options: [Option]
    let selected: Option
    let title: (Option) -> String
    let select: (Option) -> Void
    var showsContainer = true
    var animation: Animation = .smooth(duration: 0.28)

    private var selectedIndex: Int {
        options.firstIndex(of: selected) ?? 0
    }

    private var activeAnimation: Animation? {
        reduceMotion ? nil : animation
    }

    @ViewBuilder
    var body: some View {
        if showsContainer {
            controlContent
                .biliBottomTabGlassEffect(interactive: false, in: Capsule())
        } else {
            controlContent
        }
    }

    private var controlContent: some View {
        GeometryReader { proxy in
            let segmentWidth = segmentWidth(in: proxy.size.width)

            ZStack(alignment: .leading) {
                if !options.isEmpty {
                    selectedCapsule(width: segmentWidth)
                        .offset(x: 3 + CGFloat(selectedIndex) * (segmentWidth + 2))
                }

                HStack(spacing: 2) {
                    ForEach(options) { option in
                        segmentButton(for: option)
                    }
                }
                .padding(3)
            }
        }
        .frame(height: 36)
        .animation(activeAnimation, value: selectedIndex)
        .accessibilityElement(children: .contain)
    }

    private func segmentWidth(in containerWidth: CGFloat) -> CGFloat {
        let spacing = CGFloat(max(options.count - 1, 0)) * 2
        let contentWidth = max(containerWidth - 6 - spacing, 0)
        return options.isEmpty ? 0 : contentWidth / CGFloat(options.count)
    }

    private func selectedCapsule(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: 30)
            .biliBottomTabGlassEffect(interactive: true, in: Capsule())
    }

    private func segmentButton(for option: Option) -> some View {
        let isSelected = option == selected

        return Button {
            guard !isSelected else { return }
            withAnimation(activeAnimation) {
                select(option)
            }
        } label: {
            Text(title(option))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .tint(isSelected ? appTintColor : .secondary)
        .accessibilityLabel(title(option))
        .accessibilityValue(isSelected ? "已选中" : "")
    }
}
