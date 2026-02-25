//
//  UserSelectionView.swift
//  RoomScanTest
//
//  Created by Mara Ielciu on 16.02.2026.
//

import SwiftUI

struct UserSelectionView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @State private var showCreateUser = false
    @State private var newUserName = ""
    @State private var newUserEmail = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Existing Users") {
                    ForEach(userManager.users) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if userManager.currentUser?.id == user.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            userManager.switchUser(user)
                            dismiss()
                        }
                    }
                    .onDelete(perform: deleteUsers)
                }
                
                Section {
                    Button(action: { showCreateUser = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New User")
                        }
                    }
                }
            }
            .navigationTitle("Select User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Create New User", isPresented: $showCreateUser) {
                TextField("Name", text: $newUserName)
                TextField("Email", text: $newUserEmail)
                    .keyboardType(.emailAddress)
                Button("Cancel", role: .cancel) {
                    newUserName = ""
                    newUserEmail = ""
                }
                Button("Create") {
                    if !newUserName.isEmpty {
                        let user = userManager.createUser(name: newUserName, email: newUserEmail.isEmpty ? "\(newUserName.lowercased())@example.com" : newUserEmail)
                        userManager.setCurrentUser(user)
                        newUserName = ""
                        newUserEmail = ""
                        dismiss()
                    }
                }
            } message: {
                Text("Enter user details")
            }
        }
    }
    
    private func deleteUsers(at offsets: IndexSet) {
        for index in offsets {
            userManager.deleteUser(userManager.users[index])
        }
    }
}

#Preview {
    UserSelectionView()
        .environmentObject(UserManager())
}
