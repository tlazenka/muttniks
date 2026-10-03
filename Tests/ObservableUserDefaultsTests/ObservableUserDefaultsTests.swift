import Foundation
import XCTest

@testable import ObservableUserDefaults

private extension UserDefaults {
    @DefaultKey var testBool: Bool
    @DefaultKey var testInt: Int
    @DefaultKey var testDouble: Double
    @DefaultKey var testFloat: Float
    @DefaultKey var testString: String?
    @DefaultKey var testData: Data?
    @DefaultKey var testURL: URL?
    @DefaultKey var testArray: [Any]?
    @DefaultKey var testDictionary: [String: Any]?
    @DefaultKey("custom.persisted.key") var renamedProperty: Bool
}

final class ObservableUserDefaultsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ObservableUserDefaultsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testBoolDefaultsToFalseAndRoundTrips() {
        XCTAssertFalse(defaults.testBool)
        defaults.testBool = true
        XCTAssertTrue(defaults.testBool)
        XCTAssertTrue(defaults.bool(forKey: "testBool"))
    }

    func testIntDefaultsToZeroAndRoundTrips() {
        XCTAssertEqual(defaults.testInt, 0)
        defaults.testInt = 32
        XCTAssertEqual(defaults.testInt, 32)
        XCTAssertEqual(defaults.integer(forKey: "testInt"), 32)
    }

    func testDoubleDefaultsToZeroAndRoundTrips() {
        XCTAssertEqual(defaults.testDouble, 0)
        defaults.testDouble = 3.25
        XCTAssertEqual(defaults.testDouble, 3.25)
    }

    func testFloatDefaultsToZeroAndRoundTrips() {
        XCTAssertEqual(defaults.testFloat, 0)
        defaults.testFloat = 1.5
        XCTAssertEqual(defaults.testFloat, 1.5)
    }

    func testStringRoundTripsAndNilRemovesKey() {
        XCTAssertNil(defaults.testString)
        defaults.testString = "testString"
        XCTAssertEqual(defaults.testString, "testString")
        defaults.testString = nil
        XCTAssertNil(defaults.object(forKey: "testString"))
    }

    func testDataRoundTripsAndNilRemovesKey() {
        let data = Data([1])
        defaults.testData = data
        XCTAssertEqual(defaults.testData, data)
        defaults.testData = nil
        XCTAssertNil(defaults.object(forKey: "testData"))
    }

    #if !os(Linux)
    // Fails on Linux
    func testURLRoundTripsAndNilRemovesKey() {
        let url = URL(string: "http://example.com")!
        defaults.testURL = url
        XCTAssertEqual(defaults.testURL, url)
        defaults.testURL = nil
        XCTAssertNil(defaults.object(forKey: "testURL"))
    }
    #endif

    func testArrayRoundTripsAndNilRemovesKey() {
        defaults.testArray = ["1", 2]
        let result = defaults.testArray
        XCTAssertEqual(result?[0] as? String, "1")
        XCTAssertEqual(result?[1] as? Int, 2)
        defaults.testArray = nil
        XCTAssertNil(defaults.object(forKey: "testArray"))
    }

    func testDictionaryRoundTripsAndNilRemovesKey() {
        defaults.testDictionary = ["name": "mockName", "count": 2]
        XCTAssertEqual(defaults.testDictionary?["name"] as? String, "mockName")
        XCTAssertEqual(defaults.testDictionary?["count"] as? Int, 2)
        defaults.testDictionary = nil
        XCTAssertNil(defaults.object(forKey: "testDictionary"))
    }

    func testExplicitKeyDoesNotUsePropertyName() {
        defaults.renamedProperty = true
        XCTAssertTrue(defaults.bool(forKey: "custom.persisted.key"))
        XCTAssertNil(defaults.object(forKey: "renamedProperty"))
    }

    func testReadsValuesWrittenThroughRawUserDefaultsAPI() {
        defaults.set(true, forKey: "testBool")
        defaults.set(17, forKey: "testInt")
        defaults.set("external", forKey: "testString")
        XCTAssertTrue(defaults.testBool)
        XCTAssertEqual(defaults.testInt, 17)
        XCTAssertEqual(defaults.testString, "external")
    }

    func testWritesAreVisibleThroughRawUserDefaultsAPI() {
        defaults.testBool = true
        defaults.testInt = 32
        defaults.testString = "typed"
        XCTAssertEqual(defaults.object(forKey: "testBool") as? Bool, true)
        XCTAssertEqual(defaults.object(forKey: "testInt") as? Int, 32)
        XCTAssertEqual(defaults.object(forKey: "testString") as? String, "typed")
    }
}

#if canImport(Combine) && canImport(ObjectiveC)
import Combine

private extension UserDefaults {
    @DefaultKey @objc dynamic var observedMatchingKey: Bool
    @DefaultKey("observed.persisted.key") @objc dynamic var observedRenamedProperty: Bool
}

extension ObservableUserDefaultsTests {
    private var foundationKVOBehaviorChanged: String {
        "This test is to document observed Foundation KVO behavior with UserDefaults"
    }

    func testFoundationKVOPropertyWritePublishesTwiceForMatchingKey() {
        var values: [Bool] = []
        let cancellable = defaults.publisher(for: \.observedMatchingKey, options: [.new])
            .sink { values.append($0) }

        defaults.observedMatchingKey = true

        XCTAssertEqual(values, [true, true], foundationKVOBehaviorChanged)
        withExtendedLifetime(cancellable) {}
    }

    func testKVOPropertyWriteCanRemoveDuplicateEmission() {
        var values: [Bool] = []
        let cancellable = defaults.publisher(for: \.observedMatchingKey, options: [.new])
            .removeDuplicates()
            .sink { values.append($0) }

        defaults.observedMatchingKey = true

        XCTAssertEqual(
            values,
            [true],
            "removeDuplicates() should filter Foundation's duplicate KVO emissions"
        )
        withExtendedLifetime(cancellable) {}
    }

    func testKVOPropertyWritePublishesWhenPropertyAndStorageKeyDiffer() {
        var values: [Bool] = []
        let cancellable = defaults.publisher(for: \.observedRenamedProperty, options: [.new])
            .sink { values.append($0) }

        defaults.observedRenamedProperty = true

        XCTAssertEqual(values, [true], foundationKVOBehaviorChanged)
        XCTAssertTrue(defaults.bool(forKey: "observed.persisted.key"))
        XCTAssertNil(defaults.object(forKey: "observedRenamedProperty"))
        withExtendedLifetime(cancellable) {}
    }

    func testRawWriteToMatchingKeyIsVisibleThroughGeneratedProperty() {
        defaults.set(true, forKey: "observedMatchingKey")
        XCTAssertTrue(defaults.observedMatchingKey)
    }

    func testRawWriteToExplicitKeyIsVisibleThroughRenamedGeneratedProperty() {
        defaults.set(true, forKey: "observed.persisted.key")
        XCTAssertTrue(defaults.observedRenamedProperty)
        XCTAssertNil(defaults.object(forKey: "observedRenamedProperty"))
    }

    func testGeneratedWriteToRenamedPropertyIsVisibleThroughRawKey() {
        defaults.observedRenamedProperty = true
        XCTAssertTrue(defaults.bool(forKey: "observed.persisted.key"))
        XCTAssertNil(defaults.object(forKey: "observedRenamedProperty"))
    }

    func testRawWritePostsDidChangeAndTypedPublisherRereadsMatchingProperty() {
        var values: [Bool] = []
        let cancellable = defaults.didChangePublisher(for: \.observedMatchingKey)
            .sink { values.append($0) }

        defaults.set(true, forKey: "observedMatchingKey")

        XCTAssertEqual(values.last, true)
        withExtendedLifetime(cancellable) {}
    }

    func testGeneratedWritePostsDidChangeAndTypedPublisherRereadsMatchingProperty() {
        var values: [Bool] = []
        let cancellable = defaults.didChangePublisher(for: \.observedMatchingKey)
            .sink { values.append($0) }

        defaults.observedMatchingKey = true

        XCTAssertEqual(values.last, true)
        withExtendedLifetime(cancellable) {}
    }

    func testRawWriteToExplicitStorageKeyPostsDidChangeAndRereadsRenamedProperty() {
        var values: [Bool] = []
        let cancellable = defaults.didChangePublisher(for: \.observedRenamedProperty)
            .sink { values.append($0) }

        defaults.set(true, forKey: "observed.persisted.key")

        XCTAssertEqual(values.last, true)
        XCTAssertNil(defaults.object(forKey: "observedRenamedProperty"))
        withExtendedLifetime(cancellable) {}
    }

    func testGeneratedWriteToRenamedPropertyPostsDidChange() {
        var notificationCount = 0
        let cancellable = defaults.didChangePublisher
            .sink { notificationCount += 1 }

        defaults.observedRenamedProperty = true

        XCTAssertGreaterThanOrEqual(notificationCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "observed.persisted.key"))
        withExtendedLifetime(cancellable) {}
    }

    func testUnrelatedRawWriteCausesTypedDidChangePublisherToReread() {
        defaults.observedRenamedProperty = true
        var values: [Bool] = []
        let cancellable = defaults.didChangePublisher(for: \.observedRenamedProperty)
            .sink { values.append($0) }

        defaults.set(32, forKey: "unrelated")

        XCTAssertEqual(values.last, true)
        withExtendedLifetime(cancellable) {}
    }

    func testRemoveDuplicatesFiltersUnrelatedDidChangeNotifications() {
        defaults.observedRenamedProperty = true
        var values: [Bool] = []
        let cancellable = defaults.didChangePublisher(for: \.observedRenamedProperty)
            .removeDuplicates()
            .sink { values.append($0) }

        defaults.set(1, forKey: "unrelated.one")
        defaults.set(2, forKey: "unrelated.two")

        XCTAssertEqual(values, [true])
        withExtendedLifetime(cancellable) {}
    }

    func testValuesConvenienceUsesAppleKVOOptions() async {
        defaults.observedMatchingKey = true

        var iterator =
            defaults
            .values(for: \.observedMatchingKey, options: [.initial])
            .makeAsyncIterator()

        let value = await iterator.next()
        XCTAssertEqual(value, true)
    }

    func testValuesConvenienceWorksWithRenamedProperty() async {
        defaults.set(true, forKey: "observed.persisted.key")

        var iterator =
            defaults
            .values(for: \.observedRenamedProperty, options: [.initial])
            .makeAsyncIterator()

        let value = await iterator.next()
        XCTAssertEqual(value, true)
    }
}
#endif

@Defaults
private struct FeatureDefaults {
    @Registered(true) var enabled: Bool
    @Registered(false) var shouldCheckContactsAutomatically: Bool
    @DefaultKey("legacyTheme") var theme: String?
}

@Defaults(.named("ObservableUserDefaultsTests.Analytics"))
private struct AnalyticsDefaults {
    @Registered(true) var analyticsEnabled: Bool
    var userID: String?
}

@Defaults(.named("ObservableUserDefaultsTests.NamedOne"))
private struct NamedOneDefaults {
    var enabled: Bool
}

@Defaults(.named("ObservableUserDefaultsTests.NamedTwo"))
private struct NamedTwoDefaults {
    var enabled: Bool
}

@Defaults
private struct AccountDefaults {
    var signedIn: Bool
}

final class DefaultsScopeTests: XCTestCase {
    private func makeStore() -> (String, UserDefaults) {
        let name = "DefaultsScopeTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return (name, store)
    }

    func testScopeUsesRootLevelKeysWithoutNamespacing() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let feature = FeatureDefaults(defaults: store)

        feature.enabled = true
        feature.shouldCheckContactsAutomatically = true

        XCTAssertTrue(store.bool(forKey: "enabled"))
        XCTAssertTrue(store.bool(forKey: "shouldCheckContactsAutomatically"))
        XCTAssertNil(store.object(forKey: "feature.enabled"))
    }

    func testExplicitPropertyKeyMismatchWorksInsideScopeBothDirections() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let feature = FeatureDefaults(defaults: store)

        feature.theme = "Choco Cooky"
        XCTAssertEqual(store.string(forKey: "legacyTheme"), "Choco Cooky")
        XCTAssertNil(store.object(forKey: "theme"))

        store.set("External", forKey: "legacyTheme")
        XCTAssertEqual(feature.theme, "External")
    }

    func testProvidingOneScopeInjectsExactStore() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults: Defaults<FeatureDefaults> = store.providing(FeatureDefaults.self)

        let feature = defaults()
        feature.enabled = true
        XCTAssertTrue(store.bool(forKey: "enabled"))
    }

    func testProvidingTwoScopesUsesOneStoreForBoth() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults: Defaults2<FeatureDefaults, AnalyticsDefaults> = store.providing(
            FeatureDefaults.self,
            AnalyticsDefaults.self
        )

        defaults(FeatureDefaults.self).shouldCheckContactsAutomatically = true
        defaults(AnalyticsDefaults.self).userID = "32"

        XCTAssertTrue(store.bool(forKey: "shouldCheckContactsAutomatically"))
        XCTAssertEqual(store.string(forKey: "userID"), "32")
    }

    func testProvidingOverridesNamedScopesDeclaredStore() {
        let (name, injected) = makeStore()
        defer { injected.removePersistentDomain(forName: name) }
        let declared = UserDefaults(suiteName: "ObservableUserDefaultsTests.Analytics")!
        declared.removePersistentDomain(forName: "ObservableUserDefaultsTests.Analytics")
        defer { declared.removePersistentDomain(forName: "ObservableUserDefaultsTests.Analytics") }

        let defaults: Defaults2<FeatureDefaults, AnalyticsDefaults> = injected.providing(
            FeatureDefaults.self,
            AnalyticsDefaults.self
        )
        defaults(AnalyticsDefaults.self).analyticsEnabled = true

        XCTAssertTrue(injected.bool(forKey: "enabled"))
        XCTAssertFalse(declared.bool(forKey: "analyticsEnabled"))
    }

    func testNamedScopeUsesDeclaredStoreWhenNotInjected() {
        let declared = UserDefaults(suiteName: "ObservableUserDefaultsTests.Analytics")!
        declared.removePersistentDomain(forName: "ObservableUserDefaultsTests.Analytics")
        defer { declared.removePersistentDomain(forName: "ObservableUserDefaultsTests.Analytics") }

        let analytics = AnalyticsDefaults()
        analytics.analyticsEnabled = true
        XCTAssertTrue(declared.bool(forKey: "analyticsEnabled"))
    }

    func testSamePropertyNameIsFineAcrossDifferentDeclaredStores() {
        let one = NamedOneDefaults()
        let two = NamedTwoDefaults()
        _ = one.enabled
        _ = two.enabled
    }

    func testProvidingThreeScopes() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults: Defaults3<FeatureDefaults, AnalyticsDefaults, AccountDefaults> = store.providing(
            FeatureDefaults.self,
            AnalyticsDefaults.self,
            AccountDefaults.self
        )

        defaults(FeatureDefaults.self).enabled = true
        defaults(AnalyticsDefaults.self).userID = "abc"
        defaults(AccountDefaults.self).signedIn = true

        XCTAssertTrue(store.bool(forKey: "enabled"))
        XCTAssertEqual(store.string(forKey: "userID"), "abc")
        XCTAssertTrue(store.bool(forKey: "signedIn"))
    }

    func testGeneratedKeysExposeResolvedPhysicalKeys() {
        XCTAssertEqual(FeatureDefaults.Keys.enabled, "enabled")
        XCTAssertEqual(FeatureDefaults.Keys.theme, "legacyTheme")
        XCTAssertEqual(FeatureDefaults.keys, ["enabled", "shouldCheckContactsAutomatically", "legacyTheme"])
    }

    func testRegisterUsesRegistrationDomainWithoutPersistingValues() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults = store.providing(FeatureDefaults.self)

        defaults.register()

        XCTAssertTrue(defaults().enabled)
        XCTAssertFalse(defaults().shouldCheckContactsAutomatically)
        XCTAssertNil(store.persistentDomain(forName: name)?["enabled"])
        XCTAssertNil(store.persistentDomain(forName: name)?["shouldCheckContactsAutomatically"])
    }

    func testPersistedValueOverridesRegisteredValueAndRemovalRevealsItAgain() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults = store.providing(FeatureDefaults.self)
        defaults.register()

        defaults().enabled = false
        XCTAssertFalse(defaults().enabled)
        XCTAssertEqual(store.persistentDomain(forName: name)?["enabled"] as? Bool, false)

        store.removeObject(forKey: FeatureDefaults.Keys.enabled)
        XCTAssertTrue(defaults().enabled)
    }

    func testCapabilitySetMergesRegistrationDefaults() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults = store.providing(FeatureDefaults.self, AnalyticsDefaults.self)

        XCTAssertEqual(defaults.registrationDefaults["enabled"] as? Bool, true)
        XCTAssertEqual(defaults.registrationDefaults["shouldCheckContactsAutomatically"] as? Bool, false)
        XCTAssertEqual(defaults.registrationDefaults["analyticsEnabled"] as? Bool, true)
    }

    func testUnsafeDefaultsExposesExactInjectedStore() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let defaults = store.providing(FeatureDefaults.self, AnalyticsDefaults.self)

        XCTAssertTrue(defaults._unsafeDefaults === store)
        XCTAssertTrue(defaults(FeatureDefaults.self)._unsafeDefaults === store)
        XCTAssertTrue(defaults(AnalyticsDefaults.self)._unsafeDefaults === store)
    }

    #if canImport(Combine)
    func testScopedDidChangePublisherRereadsTypedPropertyAfterRawWrite() {
        let (name, store) = makeStore()
        defer { store.removePersistentDomain(forName: name) }
        let feature = FeatureDefaults(defaults: store)
        var values: [Bool] = []
        let cancellable = feature.didChangePublisher(for: \.shouldCheckContactsAutomatically)
            .sink { values.append($0) }

        store.set(true, forKey: FeatureDefaults.Keys.shouldCheckContactsAutomatically)

        XCTAssertEqual(values.last, true)
        withExtendedLifetime(cancellable) {}
    }
    #endif

}
