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

    enum HistoryFilter {
        case all
        case today
        case week
        case month
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
        // No NavigationView here — already inside the root one from AppRootView
        VStack {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                Text("All").tag(HistoryFilter.all)
                Text("Today").tag(HistoryFilter.today)
                Text("This Week").tag(HistoryFilter.week)
                Text("This Month").tag(HistoryFilter.month)
            }
            .pickerStyle(.segmented)
            .padding()

            if filteredHistory.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No History")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Your furniture replacements will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(groupedHistory.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(formatDate(date))) {
                            ForEach(groupedHistory[date] ?? []) { entry in
                                HistoryRowView(entry: entry)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !filteredHistory.isEmpty {
                    Button("Clear") {
                        historyManager.clearHistory()
                    }
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
        HStack {
            Image(systemName: iconForAction(entry.action))
                .foregroundColor(colorForAction(entry.action))
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.action.rawValue.capitalized)
                    .font(.headline)
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func iconForAction(_ action: ReplacementHistory.HistoryAction) -> String {
        switch action {
        case .replaced:
            return "arrow.triangle.2.circlepath"
        case .removed:
            return "trash"
        case .updated:
            return "pencil"
        }
    }

    private func colorForAction(_ action: ReplacementHistory.HistoryAction) -> Color {
        switch action {
        case .replaced:
            return .blue
        case .removed:
            return .red
        case .updated:
            return .orange
        }
    }
}

#Preview {
    NavigationView {
        HistoryView()
            .environmentObject(HistoryManager(userManager: UserManager()))
            .environmentObject(RoomManager(userManager: UserManager()))
    }
}
