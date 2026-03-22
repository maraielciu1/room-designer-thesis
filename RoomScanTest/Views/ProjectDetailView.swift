//
//  ProjectDetailView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 10.03.2026.
//
//  Shows a single project's rooms, aggregate statistics,
//  and allows adding / removing rooms from the project.
//

import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @EnvironmentObject var roomManager: RoomManager

    let project: Project

    @State private var showAddRoomSheet = false
    @State private var showEditSheet = false
    @State private var editName: String = ""
    @State private var editDescription: String = ""
    @State private var showDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss

    private var currentProject: Project {
        projectManager.projects.first { $0.id == project.id } ?? project
    }

    private var projectRooms: [Room] {
        projectManager.rooms(for: currentProject)
    }

    private var summary: (roomCount: Int, totalArea: Float, totalVolume: Float, itemCount: Int) {
        projectManager.projectSummary(for: currentProject)
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    roomsSection
                    dangerZone
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        editName = currentProject.name
                        editDescription = currentProject.description
                        showEditSheet = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }

                    Button {
                        showAddRoomSheet = true
                    } label: {
                        Label("Add Room", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .tintedIcon()
                }
            }
        }
        .sheet(isPresented: $showAddRoomSheet) {
            addRoomSheet
        }
        .sheet(isPresented: $showEditSheet) {
            editProjectSheet
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                projectManager.deleteProject(currentProject)
                dismiss()
            }
        } message: {
            Text("This will delete the project but keep its rooms. This cannot be undone.")
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            if !currentProject.description.isEmpty {
                Text(currentProject.description)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                summaryMetric(icon: "door.left.hand.open", value: "\(summary.roomCount)", label: "Rooms")
                summaryMetric(icon: "square.dashed", value: String(format: "%.1f m²", summary.totalArea), label: "Total Area")
                summaryMetric(icon: "cube", value: String(format: "%.1f m³", summary.totalVolume), label: "Volume")
                summaryMetric(icon: "shippingbox", value: "\(summary.itemCount)", label: "Items")
            }
        }
        .padding(16)
        .glassCard()
    }

    private func summaryMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.accentGradientInline)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rooms Section

    private var roomsSection: some View {
        VStack(spacing: 12) {
            HStack {
                ThemeSectionHeader(title: "Rooms", icon: "door.left.hand.open")
                Spacer()
                Button {
                    showAddRoomSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.accentGradientInline)
                }
            }

            if projectRooms.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.accentGradientInline)
                    Text("No Rooms Yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    Text("Add scanned rooms to this project.")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassCard()
            } else {
                ForEach(projectRooms) { room in
                    roomRow(room)
                }
            }
        }
    }

    private func roomRow(_ room: Room) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.transparent")
                .font(.title3)
                .foregroundStyle(AppTheme.accentGradientInline)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)

                if let captured = room.getCapturedRoom() {
                    let m = MeasurementService.measure(captured)
                    Text("\(m.formattedFloorArea) · \(m.objectCount) objects · \(room.furnitureReplacements.count) items")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                } else {
                    Text("No scan data")
                        .font(.caption2)
                        .foregroundColor(AppTheme.tertiaryText)
                }
            }

            Spacer()

            Button {
                projectManager.removeRoom(room, from: currentProject)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(AppTheme.glowRed.opacity(0.8))
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            ThemeSectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle")
                .padding(.top, 8)

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Project")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.glowRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.glowRed.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.glowRed.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Add Room Sheet

    private var addRoomSheet: some View {
        let unassigned = projectManager.unassignedRooms()
        return NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                if unassigned.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.accentGradientInline)
                        Text("No Available Rooms")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("All your rooms are already assigned to projects. Scan a new room first.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(unassigned) { room in
                                Button {
                                    projectManager.addRoom(room, to: currentProject)
                                    showAddRoomSheet = false
                                } label: {
                                    addRoomRow(room)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddRoomSheet = false }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addRoomRow(_ room: Room) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.transparent")
                .font(.title3)
                .foregroundStyle(AppTheme.accentGradientInline)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Text(room.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppTheme.accentGradientInline)
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Edit Sheet

    private var editProjectSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: 0x0B0D17).ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("Project name", text: $editName)
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
                        Text("Description")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.secondaryText)
                        TextField("Description…", text: $editDescription, axis: .vertical)
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
                        var updated = currentProject
                        updated.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.description = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        projectManager.updateProject(updated)
                        showEditSheet = false
                    } label: {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditSheet = false }
                        .foregroundColor(AppTheme.glowCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
