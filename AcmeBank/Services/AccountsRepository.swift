import Foundation

/// What the dashboard (and any future feature) depends on for the list
/// of accounts. Constructor-injected \u2014 there is intentionally no shared
/// singleton.
///
/// ## Async / throws
/// `fetchAccounts()` is `async throws` because the production
/// implementation will hit the network. The stub returns synchronously
/// under the hood but still satisfies the signature so the call site is
/// identical across stub and real implementations.
public protocol AccountsRepository {
    /// Returns every account visible to the signed-in customer, in
    /// dashboard display order (the repository decides the order \u2014 the
    /// UI must not re-sort, so that the fixture order matches the
    /// mockup).
    func fetchAccounts() async throws -> [Account]
}

// MARK: - BFF base URL

/// Resolves the BFF base URL. Reads `API_BASE_URL` from the app's
/// Info.plist when present (so a developer running the BFF locally can
/// point at `http://localhost:7071`), and otherwise defaults to the
/// deployed `develop` BFF so the authenticated `/v1/home` call works
/// out of the box without any local backend running.
public enum APIConfig {
    /// Override key looked up in the bundle's Info.plist. Optional —
    /// the default below is used when it's absent or blank.
    public static let baseURLInfoKey = "API_BASE_URL"

    /// Deployed develop BFF. HTTPS, so it satisfies App Transport
    /// Security with no exception needed.
    public static let defaultBaseURL = URL(string: "https://mbdemo-bff-develop.azurewebsites.net")!

    public static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: baseURLInfoKey) as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        return defaultBaseURL
    }
}

// MARK: - BFF-backed repository (real /v1/home call)

/// `AccountsRepository` that calls the BFF `GET /v1/home` with the
/// signed-in user's Okta access token as a bearer credential and maps the
/// response's `accounts` array into `[Account]` for the dashboard.
///
/// This replaces `StubAccountsRepository` in the production composition
/// root so the dashboard renders the *real* per-user data the backend
/// returns instead of static fixtures.
///
/// ## Intentional side effect — capture the BFF contract
/// On every fetch the raw `/v1/home` response body is printed to the
/// console (pretty-printed when it parses as JSON, including the full
/// `customer` / `recent_transactions` payload that the UI does not model
/// yet). This is deliberate: it lets the exact BFF response shape be
/// captured from a real signed-in run so the Home redesign can define the
/// value objects it needs from a concrete sample. Remove the `print` once
/// the contract is pinned.
public struct BFFHomeRepository: AccountsRepository {

    /// Failure modes surfaced to the view-model. The view shows a generic
    /// banner for all of them; the console log (and the typed case) carry
    /// the detail for debugging.
    public enum RepositoryError: Error {
        /// No access token on the session — the BFF call was not attempted.
        case notAuthenticated
        /// BFF returned 401 — token rejected / expired.
        case unauthorized
        /// BFF returned a non-2xx, non-401 status.
        case server(status: Int)
        /// 2xx body did not decode into the expected shape (the raw JSON
        /// was still printed to the console for capture).
        case decoding(underlying: Error)
    }

    private let baseURL: URL
    private let accessToken: String
    private let session: URLSession

    /// - Parameters:
    ///   - baseURL:     BFF root. Defaults to `APIConfig.baseURL`.
    ///   - accessToken: Okta access token from the live `UserSession`,
    ///                  sent verbatim as `Authorization: Bearer …`.
    ///   - session:     injectable for tests; defaults to `.shared`.
    public init(baseURL: URL = APIConfig.baseURL,
                accessToken: String,
                session: URLSession = .shared) {
        self.baseURL     = baseURL
        self.accessToken = accessToken
        self.session     = session
    }

    public func fetchAccounts() async throws -> [Account] {
        guard !accessToken.isEmpty else {
            throw RepositoryError.notAuthenticated
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/home"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        // Capture the raw contract BEFORE anything can throw, so the body
        // is always available even on a decode failure or error status.
        Self.printRawBody(data, response: response)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                throw RepositoryError.unauthorized
            }
            guard (200...299).contains(http.statusCode) else {
                throw RepositoryError.server(status: http.statusCode)
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let home = try decoder.decode(HomeResponseDTO.self, from: data)
            return home.accounts.map { $0.toAccount() }
        } catch {
            throw RepositoryError.decoding(underlying: error)
        }
    }

    /// Prints the `/v1/home` body to the console — pretty-printed when it
    /// parses as JSON, otherwise the raw string — bracketed by clear
    /// banners so it's easy to find and copy out of the Xcode console.
    private static func printRawBody(_ data: Data, response: URLResponse) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body: String
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(
               withJSONObject: object,
               options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let text = String(data: pretty, encoding: .utf8) {
            body = text
        } else {
            body = String(data: data, encoding: .utf8)
                ?? "<\(data.count) non-UTF8 bytes>"
        }
        print("""

        ======== BFF GET /v1/home — HTTP \(status) ========
        \(body)
        ======== END /v1/home ========

        """)
    }
}

// MARK: - BFF wire DTOs

/// The `/v1/home` response. Only `accounts` is mapped into the UI today;
/// the rest of the payload (`customer`, `recent_transactions`, …) is left
/// unmodelled on purpose and surfaces only in the printed JSON, which is
/// what the Home redesign will use to define its value objects.
///
/// Decoded with `.convertFromSnakeCase`, so wire keys like
/// `masked_number` map onto the camelCase properties below.
private struct HomeResponseDTO: Decodable {
    let accounts: [AccountDTO]
}

/// One account from the BFF. Fields are optional and the mapping is
/// lenient so a minor contract drift renders best-effort rather than
/// failing the whole decode (the raw body is printed regardless).
private struct AccountDTO: Decodable {
    let id: String?
    let name: String?
    let maskedNumber: String?
    let balance: Decimal?
    let type: String?

    func toAccount() -> Account {
        Account(
            id:           id ?? UUID().uuidString,
            kind:         AccountDTO.kind(from: type),
            displayName:  name ?? "Account",
            maskedNumber: maskedNumber ?? "",
            balance:      balance ?? 0
        )
    }

    /// Maps the BFF `type` string onto the app's `AccountKind`. Tolerant
    /// of the `chequing` spelling and defaults unknown/other product
    /// types (e.g. `investment`) to `.checking` so decoding never fails
    /// on an unmodelled kind.
    private static func kind(from raw: String?) -> AccountKind {
        switch (raw ?? "").lowercased() {
        case "savings":               return .savings
        case "credit":                return .credit
        case "checking", "chequing":  return .checking
        default:                      return .checking
        }
    }
}
