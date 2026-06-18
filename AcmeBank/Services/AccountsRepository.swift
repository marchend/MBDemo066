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

// MARK: - Home dashboard value objects

/// The full `/v1/home` payload the redesigned dashboard renders:
/// the signed-in `customer`, their `accounts`, and the most recent
/// transactions across those accounts. A pure value type \u2014 no UI,
/// no networking, no formatting.
public struct HomeDashboard: Equatable {
    public let customer: Customer
    public let accounts: [Account]
    public let recentTransactions: [Transaction]

    public init(
        customer: Customer,
        accounts: [Account],
        recentTransactions: [Transaction]
    ) {
        self.customer           = customer
        self.accounts           = accounts
        self.recentTransactions = recentTransactions
    }
}

/// The signed-in customer as returned by `/v1/home`. Note the BFF
/// `customer` object carries **no email** \u2014 only id, name parts, and
/// phone. The dashboard renders the initials, full name, phone, and
/// the "Customer {id}" trust row from this.
public struct Customer: Equatable {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let phoneNumber: String

    public init(id: String, firstName: String, lastName: String, phoneNumber: String) {
        self.id          = id
        self.firstName   = firstName
        self.lastName    = lastName
        self.phoneNumber = phoneNumber
    }

    /// First letter of `firstName` + first letter of `lastName`,
    /// uppercased, e.g. "BO" for "Bankuser One". Empty parts are
    /// skipped so a single-name customer still renders one letter.
    public var initials: String {
        let first = firstName.first.map { String($0) } ?? ""
        let last  = lastName.first.map { String($0) } ?? ""
        return (first + last).uppercased()
    }

    /// `firstName + " " + lastName`, with surrounding whitespace
    /// trimmed so a missing part doesn't leave a dangling space.
    public var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

/// One row of `recent_transactions` from `/v1/home`.
///
/// `postedDate` is decoded as the raw calendar-date STRING the BFF
/// sends (`"YYYY-MM-DD"`) \u2014 NOT a `Date` \u2014 because the wire value is
/// date-only and the ISO-8601 strategy throws on it. The view
/// formats it for display via a `yyyy-MM-dd` parser.
public struct Transaction: Equatable, Identifiable {
    public let id: String
    public let accountId: String
    public let postedDate: String
    public let merchantName: String
    public let amount: Decimal
    public let currencyCode: String

    public init(
        id: String,
        accountId: String,
        postedDate: String,
        merchantName: String,
        amount: Decimal,
        currencyCode: String
    ) {
        self.id           = id
        self.accountId    = accountId
        self.postedDate   = postedDate
        self.merchantName = merchantName
        self.amount       = amount
        self.currencyCode = currencyCode
    }
}

/// Data source for the redesigned Home dashboard: the full
/// `/v1/home` payload (customer + accounts + recent transactions).
/// Separate from `AccountsRepository` so the accounts-only call site
/// keeps working unchanged; production repositories conform to both.
public protocol HomeRepositoryProtocol {
    func fetchHome() async throws -> HomeDashboard
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
public struct BFFHomeRepository: AccountsRepository, HomeRepositoryProtocol {

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
        let dto = try await decodeHome()
        return dto.toDashboard().accounts
    }

    /// Decodes the FULL `/v1/home` payload — customer, accounts, and
    /// recent transactions — into the dashboard's value objects.
    /// Shares the same authenticated request / raw-body-print / error
    /// handling as `fetchAccounts()`.
    public func fetchHome() async throws -> HomeDashboard {
        let dto = try await decodeHome()
        return dto.toDashboard()
    }

    // MARK: - Shared request + decode

    /// Performs the authenticated `GET /v1/home`, prints the raw body,
    /// maps non-2xx onto `RepositoryError`, and decodes the lenient
    /// `HomeResponseDTO`. Both public fetch methods funnel through here
    /// so the request/print/error logic lives in exactly one place.
    private func decodeHome() async throws -> HomeResponseDTO {
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
            return try decoder.decode(HomeResponseDTO.self, from: data)
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

/// The `/v1/home` response, modelled in full for the redesigned
/// dashboard: `customer`, `accounts`, and `recent_transactions`.
///
/// Every field is optional / lenient on purpose: a minor contract
/// drift renders best-effort rather than failing the whole decode
/// (the raw body is printed regardless, so the real shape is always
/// recoverable from the console).
///
/// Decoded with `.convertFromSnakeCase`, so wire keys like
/// `masked_number` / `recent_transactions` map onto the camelCase
/// properties below.
private struct HomeResponseDTO: Decodable {
    let customer: CustomerDTO?
    // `[AccountDTO?]` so a single malformed element decodes to `nil`
    // and is dropped, rather than throwing the whole array.
    let accounts: [AccountDTO?]?
    let recentTransactions: [TransactionDTO?]?

    func toDashboard() -> HomeDashboard {
        HomeDashboard(
            customer:           (customer ?? CustomerDTO()).toCustomer(),
            accounts:           (accounts ?? []).compactMap { $0?.toAccount() },
            recentTransactions: (recentTransactions ?? []).compactMap { $0?.toTransaction() }
        )
    }
}

/// The `customer` object. NOTE: the BFF customer carries no email —
/// only id, name parts, and phone.
private struct CustomerDTO: Decodable {
    var id: String?
    var firstName: String?
    var lastName: String?
    var phoneNumber: String?

    func toCustomer() -> Customer {
        Customer(
            id:          id ?? "",
            firstName:   firstName ?? "",
            lastName:    lastName ?? "",
            phoneNumber: phoneNumber ?? ""
        )
    }
}

/// One account from the BFF. Fields are optional and the mapping is
/// lenient so a minor contract drift renders best-effort rather than
/// failing the whole decode (the raw body is printed regardless).
private struct AccountDTO: Decodable {
    let id: String?
    let name: String?
    let maskedNumber: String?
    let balance: Decimal?
    let availableBalance: Decimal?
    let type: String?
    let currencyCode: String?

    func toAccount() -> Account {
        let bal = balance ?? 0
        return Account(
            id:               id ?? UUID().uuidString,
            kind:             AccountDTO.kind(from: type),
            displayName:      name ?? "Account",
            maskedNumber:     maskedNumber ?? "",
            balance:          bal,
            availableBalance: availableBalance ?? bal,
            currencyCode:     currencyCode ?? "USD"
        )
    }

    /// Maps the BFF `type` string onto the app's `AccountKind`. The
    /// wire values are UPPERCASE (CHEQUING / SAVINGS / CREDIT /
    /// INVESTMENT); we lowercase first and tolerate the US `checking`
    /// spelling. Unknown types default to `.checking` so decoding
    /// never fails on an unmodelled kind.
    private static func kind(from raw: String?) -> AccountKind {
        switch (raw ?? "").lowercased() {
        case "savings":               return .savings
        case "credit":                return .credit
        case "investment":            return .investment
        case "checking", "chequing":  return .checking
        default:                      return .checking
        }
    }
}

/// One `recent_transactions` row. `postedDate` is decoded as the raw
/// `"YYYY-MM-DD"` STRING (the wire value is date-only; `.iso8601`
/// would throw on it). `merchant_name` is the only label the BFF
/// sends — there is no `description` / `category`.
private struct TransactionDTO: Decodable {
    let id: String?
    let accountId: String?
    let postedDate: String?
    let merchantName: String?
    let amount: Decimal?
    let currencyCode: String?

    func toTransaction() -> Transaction {
        Transaction(
            id:           id ?? UUID().uuidString,
            accountId:    accountId ?? "",
            postedDate:   postedDate ?? "",
            merchantName: merchantName ?? "",
            amount:       amount ?? 0,
            currencyCode: currencyCode ?? "USD"
        )
    }
}
