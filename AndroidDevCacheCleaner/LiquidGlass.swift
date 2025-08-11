import SwiftUI

// MARK: - App-wide Settings

/// Holds user preferences that persist across launches via @AppStorage.
/// Inject via .environmentObject(AppSettings()) at the root.
class AppSettings: ObservableObject {
    @AppStorage("liquidGlassEnabled") var liquidGlassEnabled: Bool = true
}

// MARK: - Liquid Glass View Modifier

/// Applies `.glassEffect()` on macOS Tahoe 26+ when enabled.
/// For buttons, prefer `liquidGlassButton(…)` helpers below to get a bordered fallback on older OS versions or when disabled.
/// Usage: anyView.liquidGlass(shape: .capsule, tint: .blue)
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if settings.liquidGlassEnabled {
                let glass: Glass = buildGlass()
                content.glassEffect(glass, in: shape)
            } else {
                content
            }
        } else {
            content
        }
    }

    @available(macOS 26, *)
    private func buildGlass() -> Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive  { g = g.interactive() }
        return g
    }
}

extension View {
    /// Conditionally applies Liquid Glass based on AppSettings and OS availability.
    func liquidGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Convenience overload — defaults to capsule shape (Apple's recommended default).
    func liquidGlass(tint: Color? = nil, interactive: Bool = false) -> some View {
        liquidGlass(in: Capsule(), tint: tint, interactive: interactive)
    }
}

// MARK: - Button convenience with fallback styles

extension Button {
    /// Applies Liquid Glass to the button's label when available. Falls back to bordered styles when Liquid Glass is disabled or unavailable.
    /// - Parameters:
    ///   - tint: Optional tint for the glass effect.
    ///   - interactive: Whether to enable interactive glass.
    ///   - prominentFallback: When falling back, use `.borderedProminent` if true, otherwise `.bordered`.
    ///   - shape: Shape used for the glass effect when available. Defaults to `Capsule()` which matches Apple's guidance for buttons.
    func liquidGlassButton<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        prominentFallback: Bool = false,
        in shape: S = Capsule()
    ) -> some View {
        modifier(_LiquidGlassButtonModifier(tint: tint, interactive: interactive, prominentFallback: prominentFallback, shape: shape))
    }
}

private struct _LiquidGlassButtonModifier<S: Shape>: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let prominentFallback: Bool
    let shape: S
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *), settings.liquidGlassEnabled {
                content.liquidGlass(in: shape, tint: tint, interactive: interactive)
            } else {
                if prominentFallback {
                    content.buttonStyle(.borderedProminent)
                } else {
                    content.buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - Toggle, Menu, and Picker conveniences with fallback styles

extension Toggle {
    /// Applies Liquid Glass to the toggle's label container when available. Falls back to a plain style otherwise.
    /// Note: Toggle doesn't use bordered styles; we keep a clean fallback appearance.
    func liquidGlassToggle<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S = Capsule()
    ) -> some View {
        modifier(_LiquidGlassToggleModifier(tint: tint, interactive: interactive, shape: shape))
    }
}

private struct _LiquidGlassToggleModifier<S: Shape>: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let shape: S
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *), settings.liquidGlassEnabled {
                content.liquidGlass(in: shape, tint: tint, interactive: interactive)
            } else {
                content.toggleStyle(.automatic)
            }
        }
    }
}

extension Menu {
    /// Applies Liquid Glass to the menu's label when available. Falls back to bordered menu style when unavailable.
    func liquidGlassMenu<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        prominentFallback: Bool = false,
        in shape: S = Capsule()
    ) -> some View {
        modifier(_LiquidGlassMenuModifier(tint: tint, interactive: interactive, prominentFallback: prominentFallback, shape: shape))
    }
}

private struct _LiquidGlassMenuModifier<S: Shape>: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let prominentFallback: Bool
    let shape: S
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *), settings.liquidGlassEnabled {
                content.liquidGlass(in: shape, tint: tint, interactive: interactive)
            } else {
                if prominentFallback {
                    content.buttonStyle(.borderedProminent)
                } else {
                    content.buttonStyle(.bordered)
                }
            }
        }
    }
}

extension Picker {
    /// Applies Liquid Glass to the picker's label container when available. Falls back to the default picker style otherwise.
    func liquidGlassPicker<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S = Capsule()
    ) -> some View {
        modifier(_LiquidGlassPickerModifier(tint: tint, interactive: interactive, shape: shape))
    }
}

private struct _LiquidGlassPickerModifier<S: Shape>: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let shape: S
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *), settings.liquidGlassEnabled {
                content.liquidGlass(in: shape, tint: tint, interactive: interactive)
            } else {
                content.pickerStyle(.automatic)
            }
        }
    }
}

// MARK: - App-wide Toolbar / Background convenience

/// Applies a consistent toolbar background and enables Liquid Glass-friendly surfaces
/// while preserving the default system look when Liquid Glass is disabled or unavailable.
struct AppWideGlassToolbar: ViewModifier {
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        content
            .applyToolbarBackground(settings: settings)
    }
}

private extension View {
    /// Chooses a toolbar background that complements Liquid Glass controls.
    /// On supported macOS with Liquid Glass enabled, we use a subtle material background.
    /// Otherwise we keep the default appearance.
    func applyToolbarBackground(settings: AppSettings) -> some View {
        Group {
            if #available(macOS 26, *), settings.liquidGlassEnabled {
                self.toolbarBackground(.regularMaterial, for: .automatic)
            } else {
                self.toolbarBackground(.visible, for: .automatic)
            }
        }
    }
}

extension View {
    /// Apply this at the top-level content of a WindowGroup to get a consistent toolbar background.
    func appWideGlassToolbar() -> some View { modifier(AppWideGlassToolbar()) }
}

// MARK: - Glass Background Modifier

/// Applies a glass effect as a background layer on panels/banners.
/// Falls back to a standard material background on older OS versions.
struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    @EnvironmentObject private var settings: AppSettings

    func body(content: Content) -> some View {
        if #available(macOS 26, *), settings.liquidGlassEnabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)       // Tahoe refines this automatically
                        .glassEffect(.regular, in: RoundedRectangle(
                            cornerRadius: cornerRadius, style: .continuous))
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                )
        }
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

