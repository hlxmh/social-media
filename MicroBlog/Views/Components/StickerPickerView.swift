import SwiftUI

struct StickerPickerView: View {
    let onPick: (Sticker, StickerTint) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTint: StickerTint = .pink

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                tintRow
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Sticker.allCases) { sticker in
                            Button {
                                onPick(sticker, selectedTint)
                                dismiss()
                            } label: {
                                stickerCell(sticker)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var tintRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StickerTint.allCases) { tint in
                    Circle()
                        .fill(tint.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(Color.primary.opacity(selectedTint == tint ? 0.9 : 0),
                                            lineWidth: 2)
                        )
                        .onTapGesture { selectedTint = tint }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func stickerCell(_ sticker: Sticker) -> some View {
        Group {
            switch sticker.glyph {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: 34))
                    .foregroundStyle(selectedTint.color)
            case .emoji(let emoji):
                Text(emoji).font(.system(size: 36))
            }
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#if DEBUG
#Preview("Sticker picker") {
    StickerPickerView { _, _ in }
}
#endif
