//
//  LoginView.swift
//  Login screen + Home screen of the sample app.
//
//  Identifiers:
//    login_title, username_field, password_field, remember_switch,
//    login_button, error_label, welcome_label, signed_in_label,
//    remember_status_label, logout_button
//

import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loggedInUser: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Login")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("login_title")
                    .padding(.top, 40)

                HStack(spacing: 10) {
                    Image(systemName: "person").foregroundStyle(.secondary)
                    TextField("Enter username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .accessibilityIdentifier("username_field")
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.4)))

                HStack(spacing: 10) {
                    Image(systemName: "lock").foregroundStyle(.secondary)
                    SecureField("Enter password", text: $password)
                        .accessibilityIdentifier("password_field")
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.4)))

                Toggle("Remember me", isOn: $rememberMe)
                    .tint(.green)
                    .accessibilityIdentifier("remember_switch")

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("error_label")
                }

                Button(action: login) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Login").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .accessibilityIdentifier("login_button")

                Spacer()
            }
            .padding(24)
            .navigationDestination(isPresented: isLoggedIn) {
                HomeView(username: loggedInUser ?? "", rememberMe: rememberMe) {
                    loggedInUser = nil
                    password = ""
                }
            }
        }
    }

    private var isLoggedIn: Binding<Bool> {
        Binding(get: { loggedInUser != nil },
                set: { if !$0 { loggedInUser = nil } })
    }

    private func login() {
        errorMessage = nil
        isLoading = true
        // Simulated network delay so the workflow's waitTime / waits are meaningful.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            if AuthService.validate(username: username, password: password) {
                loggedInUser = username
            } else {
                errorMessage = "Invalid username or password"
            }
        }
    }
}

struct HomeView: View {
    let username: String
    let rememberMe: Bool
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .accessibilityIdentifier("success_image")
            Text("Welcome!")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("welcome_label")
            Text("Signed in as \(username)")
                .accessibilityIdentifier("signed_in_label")
            Text(rememberMe ? "Remember me: On" : "Remember me: Off")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("remember_status_label")
            Button("Log out", action: onLogout)
                .accessibilityIdentifier("logout_button")
                .padding(.top, 20)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
