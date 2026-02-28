//
//  MarketplaceHomeView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 28.02.2026.
//

import SwiftUI

/// Main marketplace browse screen — grid of community 3D models with search & filtering.
struct MarketplaceHomeView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var marketplaceManager: MarketplaceManager

    @State private var searchText = ""
    @State private var selectedCategory = "all"
    @State private var showUpload = false
    @State private var showProfile = false
    @State private var selectedItem: MarketplaceItem?

    private let categories = ["all"] + FurnitureCategory.allCases.map(\.rawValue)

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color(hex: 0x0B0D17).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Bar ──
                topBar

                // ── Category Pills ──
                categoryScroller
                    .padding(.top, 8)

                // ── Content ──
                if marketplaceManager.isLoading && marketplaceManager.items.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.glowCyan)
                        .scaleEffect(1.2)
                    Spacer()
                } else if marketplaceManager.items.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(marketplaceManager.items) { item in
                                MarketplaceGridCard(item: item)
                                    .onTapGesture { selectedItem = item }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            MarketplaceItemDetailView(item: item)
                .environmentObject(authManager)
                .environmentObject(marketplaceManager)
        }
        .sheet(isPresented: $showUpload) {
            UploadModelView()
                .environmentObject(authManager)
                .environmentObject(marketplaceManager)
        }
        .sheet(isPresented: $showProfile) {
            MarketplaceProfileView()
                .environmentObject(authManager)
                .environmentObject(marketplaceManager)
        }
        .task {
            await marketplaceManager.fetchItems()
        }
        .onChange(of: selectedCategory) { _, newValue in
            Task {
                await marketplaceManager.fetchItems(
                    category: newValue,
                    searchText: searchText.isEmpty ? nil : searchText
                )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Marketplace")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    if let user = authManager.marketplaceUser {
                        Text("Hi, \(user.displayName)")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }

                Spacer()

                Button { showUpload = true } label: {
                    Image(systemName: "plus")
                        .tintedIconGradient()
                }

                Button { showProfile = true } label: {
                    Image(systemName: "person.circle")
                        .tintedIcon(AppTheme.glowViolet)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.secondaryText)
                TextField("Search models...", text: $searchText)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task {
                            await marketplaceManager.fetchItems(
                                category: selectedCategory,
                                searchText: searchText.isEmpty ? nil : searchText
                            )
                        }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task { await marketplaceManager.fetchItems(category: selectedCategory) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.tertiaryText)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Categories

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat == "all" ? "All" : cat.capitalized)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(selectedCategory == cat ? .white : AppTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Group {
                                    if selectedCategory == cat {
                                        AppTheme.accentGradientInline
                                    } else {
                                        Color.white.opacity(0.06)
                                    }
                                }
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedCategory == cat
                                            ? Color.clear
                                            : Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.tertiaryText)
            Text("No models yet")
                .font(.headline)
                .foregroundColor(AppTheme.secondaryText)
            Text("Be the first to share a 3D scan!")
                .font(.caption)
                .foregroundColor(AppTheme.tertiaryText)
            Button("Upload Model") { showUpload = true }
                .buttonStyle(GradientButtonStyle())
        }
    }
}

// MARK: - Grid Card

struct MarketplaceGridCard: View {
    let item: MarketplaceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.glowViolet.opacity(0.12), AppTheme.glowCyan.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)

                Image(systemName: item.furnitureCategory.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentGradientInline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.category.capitalized)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.glowCyan)

                HStack(spacing: 12) {
                    Label("\(item.downloadCount)", systemImage: "arrow.down.circle")
                    Label("\(item.likeCount)", systemImage: "heart")
                }
                .font(.caption2)
                .foregroundColor(AppTheme.tertiaryText)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .glassCard(cornerRadius: 14)
    }
}
