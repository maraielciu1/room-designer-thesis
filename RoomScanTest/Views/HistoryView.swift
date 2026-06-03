//
//  HistoryView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var roomManager: RoomManager
    @State private var selectedFilter: HistoryFilter = .all

    enum HistoryFilter: String, CaseIterable {
        case all   = "All"
        case today = "Today"
        case week  = "Week"
        case month = "Month"
    }

    var filteredHistory: [ReplacementHistory] {
        let allHistory = historyManager.getHistoryForUser()

        switch selectedFilter {
        case .all:
            return allHistory
        case .today:
            return allHistory.filter { Calendar.current.isDateInToday($0.timestamp) }
        case .week:
            return allHistory.filter { Calendar.current.isDate($0.timestamp, equalTo: Date(), toGranularity: .weekOfYear) }
        case .month:
            return allHistory.filter { Calendar.current.isDate($0.timestamp, equalTo: Date(), toGranularity: .month) }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Custom segmented picker ──
                HStack(spacing: 6) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedFilter = filter } }) {
                            Text(filter.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(selectedFilter == filter ? .white : AppTheme.secondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedFilter == filter
                                    ? AnyShapeStyle(AppTheme.accentGradientInline)
                                    : AnyShapeStyle(AppTheme.secondaryTint.opacity(0.35))
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if filteredHistory.isEmpty {
                    Spacer()
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.glowViolet.opacity(0.10))
                                .frame(width: 100, height: 100)
                                .blur(radius: 25)
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.accentGradientInline)
                        }
                        Text("No History")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Your furniture replacements will appear here")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(groupedHistory.keys.sorted(by: >), id: \.self) { date in
                                // ── Date section header ──
                                ThemeSectionHeader(title: formatDate(date), icon: "calendar")
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)

                                ForEach(groupedHistory[date] ?? []) { entry in
                                    HistoryRowView(entry: entry)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .appNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !filteredHistory.isEmpty {
                    Button("Clear") {
                        historyManager.clearHistory()
                    }
                    .foregroundColor(AppTheme.glowRed)
                }
            }
        }
    }

    private var groupedHistory: [Date: [ReplacementHistory]] {
        Dictionary(grouping: filteredHistory) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct HistoryRowView: View {
    let entry: ReplacementHistory

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorForAction(entry.action).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: iconForAction(entry.action))
                    .foregroundColor(colorForAction(entry.action))
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.action.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(2)
                }
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }

            Spacer()
        }
        .padding(12)
        .glassCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func iconForAction(_ action: ReplacementHistory.HistoryAction) -> String {
        switch action {
        case .replaced: return "arrow.triangle.2.circlepath"
        case .removed:  return "trash"
        case .updated:  return "pencil"
        }
    }

    private func colorForAction(_ action: ReplacementHistory.HistoryAction) -> Color {
        switch action {
        case .replaced: return AppTheme.glowCyan
        case .removed:  return AppTheme.glowRed
        case .updated:  return AppTheme.glowOrange
        }
    }
}

#Preview {
    NavigationView {
        HistoryView()
            .environmentObject(HistoryManager(userManager: UserManager()))
            .environmentObject(RoomManager(userManager: UserManager()))
    }
    .preferredColorScheme(.dark)
}
