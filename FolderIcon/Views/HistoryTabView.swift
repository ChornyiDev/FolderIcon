import AppKit
import SwiftUI

struct HistoryTabView: View {
    @Bindable var state: AppState
    var onApply: (IconSnapshot) -> Void = { _ in }

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if state.history.entries.isEmpty {
                    emptyState
                } else {
                    SectionCard(
                        title: "Applied Icons",
                        subtitle: "\(state.history.entries.count)") {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(state.history.entries) { entry in
                                    cell(entry)
                                }
                            }
                        }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text("No history yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Applied folder icons will appear here")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func cell(_ entry: HistoryStore.Entry) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: entry.image)
                .resizable()
                .scaledToFit()
                .frame(height: 90)
                .frame(maxWidth: .infinity)
                .padding(6)
                .background(Color.gray.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.05)))
                .contentShape(Rectangle())
                .onTapGesture {
                    if let snapshot = entry.snapshot {
                        onApply(snapshot)
                    }
                }
                .onHover { hovering in
                    if hovering && entry.snapshot != nil {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
                .help(
                    entry.snapshot != nil
                        ? "\(formatted(entry.date)) — Click to re-apply"
                        : formatted(entry.date))

            Button(action: { state.history.delete(entry) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(4)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 1)
            }
            .buttonStyle(.plain)
            .padding(4)
            .help("Remove from history")
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
