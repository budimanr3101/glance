import SwiftUI

struct FileShelfOverlayView: View {
    let controller: FileShelfOverlayController

    private var style: NotchPanelStyle {
        controller.geometry.style
    }

    private var closedSize: CGSize {
        controller.geometry.closedSize
    }

    private var openSize: CGSize {
        switch style {
        case .notch:
            return CGSize(width: 300, height: 86)
        case .pill:
            return CGSize(width: 280, height: 72)
        }
    }

    private var bodySize: CGSize {
        controller.isVisible ? openSize : closedSize
    }

    private var topRadius: CGFloat {
        switch style {
        case .notch:
            return controller.isVisible ? 18 : NotchGeometry.closedTopRadius
        case .pill:
            return bodySize.height / 2
        }
    }

    private var bottomRadius: CGFloat {
        switch style {
        case .notch:
            return controller.isVisible ? 22 : NotchGeometry.closedBottomRadius
        case .pill:
            return bodySize.height / 2
        }
    }

    var body: some View {
        ZStack {
            if let presentation = controller.presentation {
                FileShelfView(presentation: presentation)
                    .opacity(controller.isVisible ? 1 : 0)
                    .scaleEffect(controller.isVisible ? 1 : 0.8)
            }
        }
        .frame(
            width: bodySize.width + NotchGeometry.flareAllowance(topRadius: topRadius, style: style),
            height: bodySize.height
        )
        .background(Color.black)
        .clipShape(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, style: style))
        .offset(y: style == .pill ? NotchGeometry.pillTopGap : 0)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: controller.isVisible)
        .frame(
            width: NotchGeometry.windowSize(for: style).width,
            height: NotchGeometry.windowSize(for: style).height,
            alignment: .top
        )
    }
}
