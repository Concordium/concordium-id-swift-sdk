import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A single step indicator with title and active state.
struct StepView: View {
    let title: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .strokeBorder(isActive ? Color.clear : Color.black, lineWidth: 1)
                .background(
                    Circle().fill(isActive ? Color(#colorLiteral(red: 0.0, green: 0.282, blue: 0.655, alpha: 1)) : Color.clear)
                )
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .multilineTextAlignment(.leading)
                .foregroundColor(isActive ? Color.black : Color.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
    }
}

/// A thin line connecting step indicators.
struct ConnectingLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.2))
            .frame(height: 1)
            .frame(maxWidth: 50)
            .offset(y: -18)
    }
}


