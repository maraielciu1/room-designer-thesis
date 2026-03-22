//
//  ProjectListView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Lists all multi-room projects for the current user,
//  with creation, deletion, and navigation to project details.
//

import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var roomManager: RoomManager

    @State private var showCreateSheet = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(hex: 0x0B0D17).opacity(0.88), for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
                .accessibilityLabel("New project")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createProjectSheet
        }
    }

    private var projects: [Project] {
        projectManager.getProjectsForCurrentUser()
    }

    // MARK: - Project List

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        projectCard(project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func projectCard(_ project: Project) -> some View {
        let summary = projectManager.projectSummary(for: project)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentGradientInline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.tertiaryText)
            }

            HStack(spacing: 16) {
                statPill(icon: "door.left.hand.open", value: "\(summary.roomCount)", label: "Rooms")
                statPill(icon: "square.dashed", value: String(format: "%.1f", summary.totalArea), label: "m²")
                statPill(icon: "shippingbox", value: "\(summary.itemCount)", label: "Items")
            }

            HStack {
                Spacer()
                Text("Updated \(project.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(AppTheme.tertiaryText)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(AppTheme.accentGradientInline)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accentGradientInline)

            Text("No Projects Yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

            Text("Create a project to group multiple room scans together — perfect for planning an entire home or workspace.")
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showCreateSheet = true
            } label: {
                Label("Create Project", systemImage: "plus.circle.fill")
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.top, 8)
        }
    }

    // MARK: - Create Sheet

    private var createProjectSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("e.g. My Apartment", text: $newProjectName)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (optional)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("Brief description…", text: $newProjectDescription, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundColor(.white)
                            .lineLimit(3...5)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    Button {
                        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        projectManager.createProject(
                            name: name,
                            description: newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        newProjectName = ""
                        newProjectDescription = ""
                        showCreateSheet = false
                    } label: {
                        Label("Create Project", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newProjectName = ""
                        newProjectDescription = ""
                        showCreateSheet = false
                    }
                    .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
