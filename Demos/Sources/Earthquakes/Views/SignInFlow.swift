import MuttniksStateMachines
import QueryBlaster
import SwiftUI

actor AuthServiceMock: NetworkAccess {
    let repository = AuthRepository()
    var previewCodes: [String: String] = [:]
    var sessions: [String: AuthRepository.Session] = [:]

    func requestVerification(for phone: PhoneNumber) async throws(AuthenticationError) -> Verification {
        do {
            let challenge = try await repository.requestCode(phone: phone.rawValue)
            previewCodes[phone.rawValue] = challenge.previewCode
            return Verification(token: phone.rawValue)
        } catch {
            throw .rejected
        }
    }

    func exchange(code: Code, verification: Verification) async throws(AuthenticationError) -> Account {
        do {
            let session = try await repository.verify(phone: verification.token, code: code.rawValue)
            sessions[session.userID] = session
            return Account(id: session.userID)
        } catch {
            throw .rejected
        }
    }

    func previewCode(for verification: Verification) -> String? { previewCodes[verification.token] }
    func session(for account: Account) -> AuthRepository.Session? { sessions[account.id] }
}

enum SignInPath: Hashable {
    case awaitingCode(Verification)
    case signedIn(Account)
}

struct SignInFlow: View {
    let completion: (AuthRepository.Session) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var authentication: Authentication = .signedOut
    @State private var phone = ""
    @State private var code = ""
    @State private var previewCode: String?
    @State private var errorMessage: String?
    @State private var processing = false
    let service = AuthServiceMock()

    var body: some View {
        NavigationStack(path: path) {
            signedOutPath
                .navigationDestination(for: SignInPath.self) {
                    switch $0 {
                    case .awaitingCode(let verification):
                        awaitingCodePath(verification)
                    case .signedIn(let account):
                        signedInPath(account)
                    }
                }
        }
        .alert(
            "Sign In",
            isPresented: Binding(
                get: {
                    errorMessage != nil
                },
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {

            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    var path: Binding<[SignInPath]> {
        Binding {
            switch authentication {
            case .signedOut: []
            case .awaitingCode(let verification): [.awaitingCode(verification)]
            case .signedIn(let account): [.signedIn(account)]
            }
        } set: { proposed in
            guard
                proposed.isEmpty,
                case .awaitingCode = authentication
            else {
                return
            }
            do {
                authentication = try Authentication.cancelVerification(from: authentication)
                code = ""
                previewCode = nil
            } catch {
                errorMessage = "State does not support cancellation"
            }
        }
    }

    var signedOutPath: some View {
        Form {
            Section {
                Marquee()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Photographs in Feed") {
                Text("Sign in to add photographs to your earthquakes feed.")
                    .foregroundStyle(.secondary)
                TextField("Phone Number", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                Button(processing ? "Requesting..." : "Continue") {
                    Task {
                        await requestCode()
                    }
                }
                .disabled(processing || phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    func awaitingCodePath(_ verification: Verification) -> some View {
        Form {
            Section("Verification") {
                Text("Code Sent to \(verification.token)").foregroundStyle(.secondary)
                if let previewCode {
                    Text("Demo Code: \(previewCode)").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                TextField("Verification Code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                Button(processing ? "Verifying..." : "Verify") {
                    Task {
                        await signIn()
                    }
                }
                .disabled(processing || code.isEmpty)
            }
        }
        .navigationTitle("Code")
        .navigationBarTitleDisplayMode(.inline)
    }

    func signedInPath(_ account: Account) -> some View {
        ProgressView()
            .navigationTitle("Signed In")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .task {
                await complete(account)
            }
    }

    @MainActor func requestCode() async {
        processing = true
        defer {
            processing = false
        }
        do {
            authentication = try await Authentication.verify(
                PhoneNumber(phone.trimmingCharacters(in: .whitespacesAndNewlines)),
                from: authentication,
                using: service
            )
            if case .awaitingCode(let verification) = authentication {
                previewCode = await service.previewCode(for: verification)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor func signIn() async {
        processing = true
        defer {
            processing = false
        }
        do {
            authentication = try await Authentication.signIn(Code(code), from: authentication, using: service)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor func complete(_ account: Account) async {
        guard case .signedIn = authentication,
            let session = await service.session(for: account)
        else {
            errorMessage = "Invalid state"
            return
        }
        completion(session)
    }
}

struct Marquee: View {
    @State private var photos: [FeedRecord] = []

    let cardWidth: CGFloat = 180
    let spacing: CGFloat = 12
    let speed: CGFloat = 30

    var body: some View {
        GeometryReader { geometryProxy in
            TimelineView(.animation) { timeline in
                let stride = cardWidth + spacing
                let cycleWidth = CGFloat(photos.count) * stride
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let offset =
                    cycleWidth > 0
                    ? -CGFloat(elapsed * speed).truncatingRemainder(dividingBy: cycleWidth)
                    : 0

                HStack(spacing: spacing) {
                    ForEach(0..<(photos.count * 2), id: \.self) { index in
                        let photo = photos[index % photos.count]

                        MarqueeCard(photo: photo)
                            .frame(width: cardWidth)
                    }
                }
                .offset(x: offset)
                .frame(
                    minWidth: geometryProxy.size.width,
                    alignment: .leading
                )
            }
        }
        .clipped()
        .frame(height: 145)
        .task {
            photos = (try? await RemotePhotosProvider().fetch()) ?? []
        }
        .accessibilityLabel("Photograph previews")
    }
}

struct MarqueeCard: View {
    let photo: FeedRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: photo.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .empty:
                    Rectangle()
                        .fill(.quaternary)

                case .failure:
                    Image(systemName: "photo")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 180, height: 110)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(
                photo.fields[FeedField.place]?.displayText
                    ?? photo.fields[FeedField.city]?.displayText
                    ?? "City"
            )
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
        .frame(width: 180, alignment: .leading)
    }
}

extension QueryValue {
    var displayText: String? {
        if case .text(let value) = self {
            value
        } else {
            nil
        }
    }
}
