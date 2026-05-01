import SwiftUI

/// An overlay element on the editor canvas that can be dragged, scaled, and
/// rotated. Position/scale/rotation write back into the bound element.
struct EditableOverlayView: View {
    @Binding var element: OverlayElement
    let canvasSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var dragStart: CGPoint? = nil
    @State private var scaleStart: Double? = nil
    @State private var rotationStart: Double? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OverlayElementView(element: element, canvasSize: canvasSize)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentColor,
                                      lineWidth: isSelected ? 1.5 : 0)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
                        )
                )

            if isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .font(.system(size: 22))
                        .background(Circle().fill(.white).padding(2))
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
            }
        }
        .position(x: element.position.x * canvasSize.width,
                  y: element.position.y * canvasSize.height)
        .gesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .simultaneousGesture(rotateGesture)
        .onTapGesture { onTap() }
        .zIndex(element.zIndex)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStart == nil { dragStart = element.position }
                let dx = value.translation.width / canvasSize.width
                let dy = value.translation.height / canvasSize.height
                guard let start = dragStart else { return }
                element.position = CGPoint(
                    x: clamp(start.x + dx, 0, 1),
                    y: clamp(start.y + dy, 0, 1)
                )
            }
            .onEnded { _ in dragStart = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if scaleStart == nil { scaleStart = element.scale }
                guard let start = scaleStart else { return }
                element.scale = clamp(start * Double(value.magnification), 0.3, 4.0)
            }
            .onEnded { _ in scaleStart = nil }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                if rotationStart == nil { rotationStart = element.rotation }
                guard let start = rotationStart else { return }
                element.rotation = start + value.rotation.radians
            }
            .onEnded { _ in rotationStart = nil }
    }
}

private func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T { min(max(x, lo), hi) }
