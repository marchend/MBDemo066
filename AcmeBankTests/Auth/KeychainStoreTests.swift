import XCTest
@testable import AcmeBank

/// Exercises `SystemKeychainStore` against the simulator's real keychain.
///
/// All keychain operations include `kSecUseDataProtectionKeychain: true`,
/// which is what makes them work on a `CODE_SIGNING_ALLOWED=NO` simulator
/// build (see `AGENT.md` → "Keychain Note"). The `queryInspector` test
/// seam lets us verify that flag is always present in the dictionary
/// before it reaches `SecItem*`.
final class KeychainStoreTests: XCTestCase {

    private var sut: SystemKeychainStore!

    override func setUp() {
        super.setUp()
        sut = SystemKeychainStore()
        // Start from a clean slate so prior test runs don't leak.
        for slot in KeychainSlot.allCases {
            try? sut.delete(slot: slot)
        }
    }

    override func tearDown() {
        // Leave the keychain clean for subsequent runs / other tests.
        for slot in KeychainSlot.allCases {
            try? sut.delete(slot: slot)
        }
        sut = nil
        super.tearDown()
    }

    // MARK: - Round-trip per slot

    func test_roundTrip_idToken() throws {
        try sut.save("id-token-value", slot: .idToken)
        XCTAssertEqual(try sut.load(slot: .idToken), "id-token-value")
        try sut.delete(slot: .idToken)
        XCTAssertNil(try sut.load(slot: .idToken))
    }

    func test_roundTrip_accessToken() throws {
        try sut.save("access-token-value", slot: .accessToken)
        XCTAssertEqual(try sut.load(slot: .accessToken), "access-token-value")
        try sut.delete(slot: .accessToken)
        XCTAssertNil(try sut.load(slot: .accessToken))
    }

    func test_roundTrip_refreshToken() throws {
        try sut.save("refresh-token-value", slot: .refreshToken)
        XCTAssertEqual(try sut.load(slot: .refreshToken), "refresh-token-value")
        try sut.delete(slot: .refreshToken)
        XCTAssertNil(try sut.load(slot: .refreshToken))
    }

    // MARK: - Save overwrites

    func test_save_overwritesExistingValue() throws {
        try sut.save("first", slot: .idToken)
        try sut.save("second", slot: .idToken)
        XCTAssertEqual(try sut.load(slot: .idToken), "second")
    }

    // MARK: - Delete is idempotent

    func test_delete_isIdempotent_onMissingItem() {
        // Slot is empty by construction (setUp wiped it). A second
        // delete on a non-existent slot must NOT throw.
        XCTAssertNoThrow(try sut.delete(slot: .accessToken))
        XCTAssertNoThrow(try sut.delete(slot: .accessToken))
    }

    // MARK: - Query shape

    func test_query_alwaysIncludesDataProtectionKeychainFlag() throws {
        var observed: [[String: Any]] = []
        sut.queryInspector = { observed.append($0) }

        try sut.save("v", slot: .accessToken)
        _ = try sut.load(slot: .accessToken)
        try sut.delete(slot: .accessToken)

        XCTAssertFalse(observed.isEmpty, "queryInspector must capture every SecItem* query")

        for q in observed {
            let dpFlag = q[kSecUseDataProtectionKeychain as String] as? Bool
            XCTAssertEqual(dpFlag, true,
                "Every keychain query must set kSecUseDataProtectionKeychain=true; " +
                "missing it breaks CI's CODE_SIGNING_ALLOWED=NO simulator builds.")

            let serviceVal = q[kSecAttrService as String] as? String
            XCTAssertEqual(serviceVal, SystemKeychainStore.service,
                "Every query must scope to the AcmeBank Okta service.")

            let accountVal = q[kSecAttrAccount as String] as? String
            XCTAssertEqual(accountVal, KeychainSlot.accessToken.account,
                "Query must address the slot we asked for.")
        }
    }

    func test_baseQuery_setsGenericPasswordClass() {
        let q = SystemKeychainStore.baseQuery(for: .idToken)
        XCTAssertEqual(q[kSecClass as String] as? String,
                       kSecClassGenericPassword as String)
    }

    // MARK: - Slot identifiers

    func test_slot_rawValuesMatchSpec() {
        XCTAssertEqual(KeychainSlot.idToken.rawValue,      "acme.okta.idToken")
        XCTAssertEqual(KeychainSlot.accessToken.rawValue,  "acme.okta.accessToken")
        XCTAssertEqual(KeychainSlot.refreshToken.rawValue, "acme.okta.refreshToken")
    }
}
