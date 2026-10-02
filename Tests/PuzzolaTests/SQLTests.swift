import Testing

@testable import Puzzola

@Test func interpolationUsesBindings() {
    let minimumMagnitude = 7.0
    let sql: SQL = "SELECT * FROM events WHERE magnitude >= \(minimumMagnitude)"

    #expect(sql.text == "SELECT * FROM events WHERE magnitude >= ?")
    #expect(sql.bindings == [.real(7.0)])
}
