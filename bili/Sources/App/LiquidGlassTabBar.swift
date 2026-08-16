import SwiftUI

private struct RootNavigationTitleHiddenKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false)
}

private extension EnvironmentValues {
    var rootNavigationTitleHidden: Binding<Bool> {
        get { self[RootNavigationTitleHiddenKey.self] }
        set { self[RootNavigationTitleHiddenKey.self] = newValue }
    }
}

private struct ScrollEdgeEffectPreferenceKey: EnvironmentKey {
    static let defaultValue: AppScrollEdgeEffectPreference = .soft
}

extension EnvironmentValues {
    var scrollEdgeEffectPreference: AppScrollEdgeEffectPreference {
        get { self[ScrollEdgeEffectPreferenceKey.self] }
        set { self[ScrollEdgeEffectPreferenceKey.self] = newValue }
    }

}

extension View {
    @ViewBuilder
    func rootFloatingTabBarContentPadding(extra: CGFloat = 0) -> some View {
        padding(.bottom, RootFloatingTabBarMetrics.contentBottomPadding + extra)
    }

    @ViewBuilder
    func nativeTopNavigationChrome() -> some View {
        Group {
            if #available(iOS 16.0, *) {
                self.toolbarBackground(.automatic, for: .navigationBar)
            } else {
                self
            }
        }
    }

    @ViewBuilder
    func rootNavigationTitle(_ title: String) -> some View {
        rootNavigationTitle(title) {
            EmptyView()
        }
    }

    @ViewBuilder
    func rootNavigationTitle<Accessory: View>(
        _ title: String,
        accessoryUsesFullWidth: Bool = false,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                self.modifier(
                    RootFloatingNavigationTitleModifier(
                        title: title,
                        accessoryUsesFullWidth: accessoryUsesFullWidth,
                        accessory: accessory
                    )
                )
            } else {
                self.navigationBarTitle(title, displayMode: .inline)
            }
        }
    }

    @ViewBuilder
    func hiddenRootNavigationTitle(_ title: String) -> some View {
        Group {
            if #available(iOS 16.0, *) {
                self
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                self
                    .navigationBarTitle(title, displayMode: .inline)
            }
        }
    }

    @ViewBuilder
    func hiddenInlineNavigationTitle() -> some View {
        Group {
            if #available(iOS 16.0, *) {
                self
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.automatic, for: .navigationBar)
            } else {
                self.navigationBarTitle("", displayMode: .inline)
            }
        }
    }

    @ViewBuilder
    func nativeTopScrollEdgeEffect(hidesRootNavigationTitle: Bool = true) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                self.modifier(TopScrollEdgeEffect(hidesRootNavigationTitle: hidesRootNavigationTitle))
            } else {
                self
            }
        }
    }

    @ViewBuilder
    func liquidGlassTabBarBackground(isDark: Bool = false) -> some View {
        self
    }

    @ViewBuilder
    func biliGlassEffect<S: Shape>(
        tint: Color = Color(.systemBackground).opacity(0.18),
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        modifier(BiliGlassEffectModifier(tint: tint, interactive: interactive, shape: shape))
    }

    @ViewBuilder
    func biliRegularGlassEffect<S: Shape>(
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        modifier(BiliRegularGlassEffectModifier(interactive: interactive, shape: shape))
    }

    @ViewBuilder
    func biliBottomTabGlassEffect<S: InsettableShape>(
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        modifier(BiliBottomTabGlassEffectModifier(interactive: interactive, shape: shape))
    }

    @ViewBuilder
    func biliGlassButtonStyle(prominent: Bool = false) -> some View {
        modifier(BiliGlassButtonStyleModifier(prominent: prominent))
    }

    @ViewBuilder
    func biliPlayerGlassButtonStyle(prominent: Bool = false) -> some View {
        buttonBorderShape(.capsule)
            .biliGlassButtonStyle(prominent: prominent)
    }

    @ViewBuilder
    func biliPlayerYouTubePillStyle(prominent: Bool = false) -> some View {
        buttonStyle(.plain)
            .background {
                Capsule()
                    .fill(.black.opacity(prominent ? 0.48 : 0.34))
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(prominent ? 0.12 : 0.08), lineWidth: 0.5)
            }
            .contentShape(Capsule())
    }

    func biliLiquidGlassForeground(shadowOpacity: Double = 0.20) -> some View {
        modifier(BiliLiquidGlassForegroundModifier(shadowOpacity: shadowOpacity))
    }
}

private struct BiliLiquidGlassForegroundModifier: ViewModifier {
    let shadowOpacity: Double

    private var foregroundColor: Color {
        .white
    }

    private var shadowColor: Color {
        .black
    }

    private var normalizedShadowOpacity: Double {
        min(max(shadowOpacity, 0), 1)
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foregroundColor)
            .shadow(
                color: shadowColor.opacity(normalizedShadowOpacity),
                radius: 2.5,
                x: 0,
                y: 1
            )
    }
}

private struct BiliGlassEffectModifier<GlassShape: Shape>: ViewModifier {
    let tint: Color
    let interactive: Bool
    let shape: GlassShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                .regular
                    .tint(tint)
                    .interactive(interactive),
                in: shape
            )
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct BiliRegularGlassEffectModifier<GlassShape: Shape>: ViewModifier {
    let interactive: Bool
    let shape: GlassShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                .regular
                    .tint(Color(.systemBackground).opacity(0.18))
                    .interactive(interactive),
                in: shape
            )
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct BiliBottomTabGlassEffectModifier<GlassShape: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let interactive: Bool
    let shape: GlassShape

    private var tabTint: Color {
        colorScheme == .dark
            ? .black.opacity(0.18)
            : Color(.systemBackground).opacity(0.16)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular
                        .tint(tabTint)
                        .interactive(interactive),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(tabTint, in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                }
        }
    }
}

private struct BiliGlassButtonStyleModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

@available(iOS 26.0, *)
struct TopScrollEdgeEffect: ViewModifier {
    @Environment(\.rootNavigationTitleHidden) private var rootNavigationTitleHidden
    @Environment(\.scrollEdgeEffectPreference) private var scrollEdgeEffectPreference
    let hidesRootNavigationTitle: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if hidesRootNavigationTitle {
            nativeStyledContent(content)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > 18
                } action: { _, isHidden in
                    guard rootNavigationTitleHidden.wrappedValue != isHidden else { return }
                    withAnimation(.smooth(duration: 0.18)) {
                        rootNavigationTitleHidden.wrappedValue = isHidden
                    }
                }
        } else {
            nativeStyledContent(content)
        }
    }

    @ViewBuilder
    private func nativeStyledContent(_ content: Content) -> some View {
        switch scrollEdgeEffectPreference {
        case .soft:
            content.scrollEdgeEffectStyle(.soft, for: .top)
        case .hard:
            content.scrollEdgeEffectStyle(.hard, for: .top)
        case .automatic:
            content.scrollEdgeEffectStyle(.automatic, for: .top)
        }
    }
}

@available(iOS 26.0, *)
private struct RootFloatingNavigationTitleModifier<Accessory: View>: ViewModifier {
    let title: String
    let accessoryUsesFullWidth: Bool
    let accessory: () -> Accessory
    @State private var isTitleHidden = false

    func body(content: Content) -> some View {
        content
            .environment(\.rootNavigationTitleHidden, $isTitleHidden)
            .hiddenRootNavigationTitle(title)
            .safeAreaBar(edge: .top, alignment: .leading, spacing: -4) {
                RootFloatingNavigationTitle(
                    title: title,
                    isTitleHidden: isTitleHidden,
                    accessoryUsesFullWidth: accessoryUsesFullWidth,
                    accessory: accessory
                )
            }
    }
}

@available(iOS 26.0, *)
private struct RootFloatingNavigationTitle<Accessory: View>: View {
    let title: String
    let isTitleHidden: Bool
    let accessoryUsesFullWidth: Bool
    let accessory: () -> Accessory

    @ViewBuilder
    var body: some View {
        Group {
            if accessoryUsesFullWidth {
                ZStack {
                    HStack {
                        titleView
                        Spacer(minLength: 12)
                    }

                    accessoryView
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    titleView
                    Spacer(minLength: 12)
                    accessoryView
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, -6)
        .padding(.bottom, 3)
    }

    private var titleView: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .opacity(isTitleHidden ? 0 : 1)
            .scaleEffect(isTitleHidden ? 0.92 : 1, anchor: .leading)
            .clipped()
    }

    private var accessoryView: some View {
        accessory()
            .opacity(isTitleHidden ? 0 : 1)
            .scaleEffect(isTitleHidden ? 0.92 : 1, anchor: .trailing)
            .allowsHitTesting(!isTitleHidden)
    }
}

enum RootFloatingTabBarMetrics {
    static let contentBottomPadding: CGFloat = 92
}
