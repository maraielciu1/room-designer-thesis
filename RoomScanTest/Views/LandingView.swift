//
//  LandingView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct LandingView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showUserSelection = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon/Logo
                Image(systemName: "house.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                // App Title
                Text("Room Designer")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Transform your space with AR")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 20)
                
                // Current User Info
                if let user = userManager.currentUser {
                    VStack(spacing: 8) {
                        Text("Welcome, \(user.name)")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button(action: { showUserSelection = true }) {
                            Text("Switch User")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.bottom, 10)
                }
                
                Spacer()
                
                VStack(spacing: 14) {
                    // Get Started — Room scanning
                    NavigationLink(destination: RoomListView()) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("My Rooms")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    }
                    
                    // My Furniture — Object scanning library
                    NavigationLink(destination: FurnitureLibraryView()) {
                        HStack {
                            Image(systemName: "cube.transparent.fill")
                            Text("My Furniture")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.25), lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showUserSelection) {
            UserSelectionView()
        }
    }
}

#Preview {
    LandingView()
        .environmentObject(UserManager())
}
