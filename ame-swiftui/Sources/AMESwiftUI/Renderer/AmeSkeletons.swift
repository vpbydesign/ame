import SwiftUI

/// Shimmer placeholder view for unresolved Ref nodes during streaming.
///
/// Per streaming.md:
/// - MUST occupy the layout slot where the resolved component will appear
/// - SHOULD render as a shimmer rectangle (animated sweeping gradient)
/// - SHOULD use default height of 48pt and full available width
/// - MUST NOT be interactive
public struct AmeSkeleton: View {

    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .shimmer()
    }
}

/// Shimmer modifier that applies a sweeping gradient animation.
///
/// The gradient sweeps horizontally across the view in a 1.5-second
/// loop with linear easing, creating a standard skeleton loading indicator.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width

                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: width * phase)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

public extension View {
    /// Applies a shimmer animation overlay to the view.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
