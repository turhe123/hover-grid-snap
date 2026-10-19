import SwiftUI

/// The rows × columns lattice. Click a cell or drag across cells to choose a rectangle; footer applies presets.
struct GridView: View {
    let columns: Int
    let rows: Int
    let presets: [Preset]
    var onPreview: (FractionRect?) -> Void
    var onCommit: (FractionRect) -> Void
    var onClose: () -> Void

    @State private var start: (c: Int, r: Int)?
    @State private var end: (c: Int, r: Int)?

    private let gridWidth: CGFloat = 264
    private var cellSize: CGSize {
        let w = gridWidth / CGFloat(columns)
        return CGSize(width: w, height: min(max(w * 0.7, 14), 220 / CGFloat(rows)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.grid.3x3.fill").foregroundStyle(Color.accentColor)
                Text("Drag across cells to snap").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Close (Esc)")
            }
            lattice
            if !presets.isEmpty {
                Divider()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(presets) { preset in
                        Button { onCommit(preset.rect) } label: {
                            Text(preset.name).font(.caption2).lineLimit(1).frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                        .onHover { onPreview($0 ? preset.rect : nil) }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: gridWidth + 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var lattice: some View {
        let size = cellSize
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected(c, r) ? Color.accentColor : Color.primary.opacity(0.1))
                            .padding(1.5)
                            .frame(width: size.width, height: size.height)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if start == nil { start = cell(at: value.startLocation, size: size) }
                    end = cell(at: value.location, size: size)
                    onPreview(selection)
                }
                .onEnded { _ in
                    if let rect = selection { onCommit(rect) }
                    start = nil
                    end = nil
                }
        )
    }

    private func cell(at point: CGPoint, size: CGSize) -> (c: Int, r: Int) {
        (min(max(Int(point.x / size.width), 0), columns - 1),
         min(max(Int(point.y / size.height), 0), rows - 1))
    }

    private var bounds: (c0: Int, r0: Int, c1: Int, r1: Int)? {
        guard let start, let end else { return nil }
        return (min(start.c, end.c), min(start.r, end.r), max(start.c, end.c), max(start.r, end.r))
    }

    private func isSelected(_ c: Int, _ r: Int) -> Bool {
        guard let b = bounds else { return false }
        return (b.c0...b.c1).contains(c) && (b.r0...b.r1).contains(r)
    }

    private var selection: FractionRect? {
        guard let b = bounds else { return nil }
        let cols = Double(columns), rws = Double(rows)
        return FractionRect(x: Double(b.c0) / cols, y: Double(b.r0) / rws,
                            w: Double(b.c1 - b.c0 + 1) / cols, h: Double(b.r1 - b.r0 + 1) / rws)
    }
}
