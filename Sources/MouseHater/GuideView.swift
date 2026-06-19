// Copyright © 2026 Vova Revenko

import SwiftUI

// MARK: - Key cap

/// A small key-cap badge, styled like a physical macOS keyboard key: a raised
/// top face with a darker side/edge peeking out along the bottom.
private struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    private let radius: CGFloat = 5
    private let lip: CGFloat = 2.5 // how much of the side shows at the bottom

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .frame(minWidth: 16, minHeight: 14)
            .padding(.horizontal, 4.5)
            .padding(.top, 1.5)
            .padding(.bottom, 1.5 + lip)
            .background {
                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.black.opacity(0.30))
                            .shadow(color: .black.opacity(0.22), radius: 1.5, y: 1)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(nsColor: .controlColor),
                                         Color(nsColor: .controlColor).opacity(0.82)],
                                startPoint: .top, endPoint: .bottom))
                            .overlay(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.75))
                            .frame(height: max(0, geo.size.height - lip))
                    }
                }
            }
    }
}

// MARK: - Inline flow layout

/// Marks a subview as "glued" to the one before it: no space in front, and it
/// can never start a wrapped line on its own (keeps trailing punctuation with
/// the key it follows).
private struct AttachedToPrevious: LayoutValueKey {
    static let defaultValue = false
}

private extension View {
    func attachedToPrevious() -> some View {
        layoutValue(key: AttachedToPrevious.self, value: true)
    }
}

/// Lays subviews out left-to-right, wrapping to new lines — so styled key caps
/// can sit inline within flowing text. Items are vertically centred per line.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = arrange(subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: y + (row.height - item.size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size))
            }
            y += row.height + lineSpacing
        }
    }

    private struct Item { let index: Int; let x: CGFloat; let size: CGSize }
    private struct Row { var items: [Item] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let attached = subviews[index][AttachedToPrevious.self]

            if row.items.isEmpty {
                row.items.append(Item(index: index, x: 0, size: size))
                row.width = size.width
                row.height = size.height
                continue
            }

            let gap = attached ? 0 : spacing
            // Attached items never break to a new line on their own.
            if !attached, row.width + gap + size.width > maxWidth {
                rows.append(row)
                row = Row()
                row.items.append(Item(index: index, x: 0, size: size))
                row.width = size.width
                row.height = size.height
            } else {
                let x = row.width + gap
                row.items.append(Item(index: index, x: x, size: size))
                row.width = x + size.width
                row.height = max(row.height, size.height)
            }
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: - Guide line

/// One flowing sentence built from text fragments and inline key caps.
/// `.tight` glues a fragment (e.g. punctuation) to the previous element.
private enum Seg {
    case text(String)
    case bold(String)
    case key(String)
    case tight(String)
}

private struct GuideLine: View {
    let segments: [Seg]
    var size: CGFloat = 13
    init(_ segments: [Seg], size: CGFloat = 13) {
        self.segments = segments
        self.size = size
    }

    var body: some View {
        FlowLayout {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                switch token {
                case .text(let s):  Text(s).font(.system(size: size))
                case .bold(let s):  Text(s).font(.system(size: size, weight: .semibold))
                case .key(let s):   KeyCap(s)
                case .tight(let s): Text(s).font(.system(size: size)).attachedToPrevious()
                }
            }
        }
    }

    /// Split text/bold runs into individual words so lines wrap naturally;
    /// keys and tight (glued) punctuation stay whole.
    private var tokens: [Seg] {
        segments.flatMap { segment -> [Seg] in
            switch segment {
            case .text(let s): return s.split(separator: " ").map { .text(String($0)) }
            case .bold(let s): return s.split(separator: " ").map { .bold(String($0)) }
            case .key, .tight: return [segment]
            }
        }
    }
}

// MARK: - Guide

/// The contents of the "Keyboard guide" popup.
struct GuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GuideLine([.text("Type the two keys shown on a cell to click it — no mouse needed.")])
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                GuideLine([.bold("Open & aim"), .text("— tap"), .key("⌘"), .tight(","),
                           .text("then type the two letters shown in your target cell, e.g."),
                           .key("a"), .key("t"), .tight(".")])
                GuideLine([.bold("Click"), .text("— a key in the 10×3 grid hits its centre.")])
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                GuideLine([.bold("Nudge"), .text("— for tiny targets, hold a final key instead of tapping: a dot appears, steer it with your free hand, then release to click.")])

                VStack(alignment: .leading, spacing: 2) {
                    GuideLine([.text("Holding a left key:")], size: 11).foregroundStyle(.secondary)
                    GuideLine([.key("I"), .tight("↑"), .key("J"), .tight("←"), .key("K"), .tight("↓"), .key("L"), .tight("→")], size: 11)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    GuideLine([.text("Holding a right key:")], size: 11).foregroundStyle(.secondary)
                    GuideLine([.key("E"), .tight("↑"), .key("S"), .tight("←"), .key("D"), .tight("↓"), .key("F"), .tight("→")], size: 11)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                GuideLine([.key("␣"), .text("— click the centre of the current region (or the cursor before any pick).")])
                GuideLine([.text("Hold"), .key("⇧"), .text("for a right-click.")])
                GuideLine([.key("⎋"), .text("or"), .key("⌘"), .text("— close without clicking.")])
            }

            GuideLine([.text("Open on a single or double"), .key("⌘"), .text("tap (set in the menu)."),
                      ], size: 11)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 440, alignment: .leading)
    }
}
