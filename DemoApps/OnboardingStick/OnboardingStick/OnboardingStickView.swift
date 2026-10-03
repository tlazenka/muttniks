//
//  ContentView.swift
//  Onboarding
//
//  Created by Francis Lazenka on 9/13/26.
//

import SwiftUI

struct OnboardingView: View {
    @State var model = OnboardingModel()
    @State var path: [Route] = []
    @State var phone = ""
    @State var code = ""

    var body: some View {
        NavigationStack(path: $path) {
            PhoneEntryView(phone: $phone, submit: submitPhone)
                .navigationTitle("Welcome In")
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .code(number):
                        CodeEntryView(
                            phoneNumber: number,
                            code: $code,
                            submit: submitCode
                        )
                        .navigationBarBackButtonHidden()
                        .navigationTitle("Welcome In")

                    case let .phoneError(message):
                        ErrorView(message: message)

                    case let .codeError(_, message):
                        ErrorView(message: message)

                    case .finished:
                        FinishedView()
                            .navigationBarBackButtonHidden()
                    }
                }
        }
        .onChange(of: path) { oldPath, newPath in
            guard newPath.count < oldPath.count,
                let poppedPath = oldPath.last
            else { return }
            switch poppedPath {
            case .phoneError:
                switch model.state {
                case .phoneError(let witness, _):
                    guard let authority = model.machine.authorizePhoneEntry(using: witness) else { return }

                    model.machine.state = .phoneEntry(consume authority)
                default:
                    break
                }
            case .codeError:
                switch model.state {
                case .codeError(let witness, _, _):
                    guard let authority = model.machine.authorizeCodeEntry(using: witness) else { return }
                    model.machine.state = .codeEntry(consume authority)
                default:
                    break
                }
            case .code, .finished:
                assertionFailure("We did not expect a pop here")
            }
        }
    }

    func submitPhone() {
        switch model.state {

        case .phoneEntry(let witness):
            if phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let authority = model.machine.authorizePhoneError(using: witness) else { return }
                model.machine.state = .phoneError(consume authority, error: OnboardingError.phoneError)
                path.append(
                    .phoneError(
                        "We don't recognize this number."
                    )
                )
            } else {
                guard let authority = model.machine.authorizeCodeEntry(using: witness) else { return }
                let number = PhoneNumber(rawValue: phone)
                model.machine.state = .codeEntry(consume authority, phoneNumber: number)
                path.append(.code(number))
            }
        default:
            break
        }
    }

    func submitCode() {
        switch model.state {
        case .codeEntry(let witness, let phoneNumber):
            if code != "123456" {
                guard let authority = model.machine.authorizeCodeError(using: witness) else { return }
                model.machine.state = .codeError(consume authority, error: OnboardingError.codeError)
                path.append(
                    .codeError(
                        phoneNumber,
                        "Try 123456 (it always works).",
                    )
                )
            } else {
                guard let authority = model.machine.authorizeFinished(using: witness) else { return }
                model.machine.state = .finished(consume authority)
                path.append(.finished)
            }
        default:
            break
        }
    }

    struct PhoneEntryView: View {
        @Binding var phone: String
        let submit: () -> Void

        @FocusState var isTextFieldFocused: Bool

        var body: some View {
            ScrollView {
                VStack {
                    CardContainer(
                        title: "Phone Number",
                        subtitle: "Please enter your phone number and tap Send Code.",
                    ) {
                        TextField("+1 777-FILM", text: $phone)
                            .textContentType(.telephoneNumber)
                            #if os(iOS)
                        .keyboardType(.phonePad)
                            #endif
                            .focused($isTextFieldFocused)
                        Button("Send Code", action: submit)
                            .buttonStyle(.borderedProminent)
                    }
                    .onAppear {
                        isTextFieldFocused = true
                    }
                }
            }
        }
    }

    struct CodeEntryView: View {
        let phoneNumber: PhoneNumber
        @Binding var code: String
        let submit: () -> Void

        @FocusState var isTextFieldFocused: Bool

        var body: some View {
            ScrollView {
                VStack {
                    CardContainer(
                        title: "Verification Code",
                        subtitle:
                            "Please enter the SMS verification code we sent and tap Sign In. You may need to wait up to 2 minutes for the code"
                    ) {
                        TextField("Verification Code", text: $code)
                            #if os(iOS)
                        .keyboardType(.phonePad)
                            #endif
                            .focused($isTextFieldFocused)
                        Button("Sign In", action: submit)
                            .buttonStyle(.borderedProminent)
                    }
                    .onAppear {
                        isTextFieldFocused = true
                    }
                }
            }
        }
    }

    struct FinishedView: View {
        var body: some View {
            ContentUnavailableView(
                "Congratulations!",
                systemImage: "service.dog.fill",
                description: Text("Consider yourself onboarded.")
            )
        }
    }

    struct CardContainer<Content: View>: View {
        let title: String
        let subtitle: String
        @ViewBuilder var content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.bold())
                Text(subtitle).foregroundStyle(.secondary)
                content
            }
            .padding(24)
            .background(.thinMaterial, in: .rect(cornerRadius: 20))
            .padding()
        }
    }

    struct ErrorView: View {
        let message: String

        var body: some View {
            ContentUnavailableView(
                "Sorry, there was an error.",
                systemImage: "figure.seated.side.right.air.distribution.upper.angled.and.dottedline.and.lower.angled",
                description: Text(message)
            )
        }
    }
}

enum OnboardingError: Error {
    case codeError
    case phoneError
}

enum Route: Hashable {
    case code(PhoneNumber)
    case phoneError(String)
    case codeError(PhoneNumber, String)
    case finished
}
