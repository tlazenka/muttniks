import Do
import XCTest

private enum TestError: Error, Equatable {
    case first
    case second
}

private struct User: Equatable {
    let id: Int
}

private struct Feed: Equatable {
    let user: User
    let count: Int
}

private final class Recorder: @unchecked Sendable {
    var secondCallCount = 0
}

private func user(_ result: Result<User, TestError>) -> Result<User, TestError> {
    result
}

private func count(
    for user: User,
    recorder: Recorder,
    result: Result<Int, TestError>
) -> Result<Int, TestError> {
    recorder.secondCallCount += 1
    return result
}

private func asyncCount(
    _ result: Result<Int, TestError>
) async -> Result<Int, TestError> {
    await Task.yield()
    return result
}

private func throwingCount(
    _ result: Result<Int, TestError>
) async throws -> Result<Int, TestError> {
    await Task.yield()
    return result
}

@Do
private func makeFeed(
    recorder: Recorder,
    userResult: Result<User, TestError>,
    countResult: Result<Int, TestError>
) -> Result<Feed, TestError> {
    let user = #bind(user(userResult))
    let count = #bind(count(for: user, recorder: recorder, result: countResult))
    Feed(user: user, count: count)
}

@Do
private func validateThenReturn(
    _ validation: Result<Void, TestError>,
    value: Result<Int, TestError>
) -> Result<Int, TestError> {
    #bind(validation)
    #bind(value)
}

@Do
private func explicitReturnValue(_ value: Int) -> Result<Int, TestError> {
    return value
}

@Do
private func implicitFinalValue(_ value: Int) -> Result<Int, TestError> {
    value
}

@Do
private func explicitReturnedSuccess(_ value: Int) -> Result<Int, TestError> {
    return .success(value)
}

@Do
private func implicitFinalSuccess(_ value: Int) -> Result<Int, TestError> {
    .success(value)
}

@Do
private func explicitReturnedFailure() -> Result<Int, TestError> {
    return .failure(.first)
}

@Do
private func implicitFinalFailure() -> Result<Int, TestError> {
    .failure(.second)
}

@Do
private func explicitTailBind(
    _ value: Result<Int, TestError>
) -> Result<Int, TestError> {
    return #bind(value)
}

@Do
private func implicitTailBind(
    _ value: Result<Int, TestError>
) -> Result<Int, TestError> {
    #bind(value)
}

@Do
private func earlyReturnStillWorks(_ returnEarly: Bool) -> Result<Int, TestError> {
    if returnEarly {
        return 1
    }

    2
}

@Do
private func mixedEffects(
    first: Result<Int, TestError>,
    second: Result<Int, TestError>,
    third: Result<Int, TestError>
) async throws -> Result<Int, TestError> {
    let a = #bind(first)
    let b = #bind(await asyncCount(second))
    let c = #bind(try await throwingCount(third))
    a + b + c
}

final class DoIntegrationTests: XCTestCase {
    func testSuccessfulProgramReadsLikeStraightLineCodeWithFinalExpression() {
        let recorder = Recorder()

        let result = makeFeed(
            recorder: recorder,
            userResult: .success(User(id: 7)),
            countResult: .success(3)
        )

        XCTAssertEqual(result, .success(Feed(user: User(id: 7), count: 3)))
        XCTAssertEqual(recorder.secondCallCount, 1)
    }

    func testFailureShortCircuitsRemainingProgram() {
        let recorder = Recorder()

        let result = makeFeed(
            recorder: recorder,
            userResult: .failure(.first),
            countResult: .success(3)
        )

        XCTAssertEqual(result, .failure(.first))
        XCTAssertEqual(recorder.secondCallCount, 0)
    }

    func testLaterFailureIsPropagated() {
        let recorder = Recorder()

        let result = makeFeed(
            recorder: recorder,
            userResult: .success(User(id: 7)),
            countResult: .failure(.second)
        )

        XCTAssertEqual(result, .failure(.second))
        XCTAssertEqual(recorder.secondCallCount, 1)
    }

    func testNonFinalBareBindDiscardsVoidSuccessAndFinalBareBindIsTailBind() {
        XCTAssertEqual(
            validateThenReturn(.success(()), value: .success(32)),
            .success(32)
        )
        XCTAssertEqual(
            validateThenReturn(.failure(.first), value: .success(32)),
            .failure(.first)
        )
        XCTAssertEqual(
            validateThenReturn(.success(()), value: .failure(.second)),
            .failure(.second)
        )
    }

    func testClosingForms() {
        XCTAssertEqual(explicitReturnValue(10), .success(10))
        XCTAssertEqual(implicitFinalValue(11), .success(11))

        XCTAssertEqual(explicitReturnedSuccess(12), .success(12))
        XCTAssertEqual(implicitFinalSuccess(13), .success(13))

        XCTAssertEqual(explicitReturnedFailure(), .failure(.first))
        XCTAssertEqual(implicitFinalFailure(), .failure(.second))

        XCTAssertEqual(explicitTailBind(.success(14)), .success(14))
        XCTAssertEqual(explicitTailBind(.failure(.first)), .failure(.first))
        XCTAssertEqual(implicitTailBind(.success(15)), .success(15))
        XCTAssertEqual(implicitTailBind(.failure(.second)), .failure(.second))
    }

    func testReturnRemainsAvailableForEarlyExit() {
        XCTAssertEqual(earlyReturnStillWorks(true), .success(1))
        XCTAssertEqual(earlyReturnStillWorks(false), .success(2))
    }

    func testBindCoexistsWithRealAsyncAwaitAndThrows() async throws {
        let success = try await mixedEffects(
            first: .success(1),
            second: .success(2),
            third: .success(3)
        )
        XCTAssertEqual(success, .success(6))

        let failure = try await mixedEffects(
            first: .success(1),
            second: .failure(.second),
            third: .success(3)
        )
        XCTAssertEqual(failure, .failure(.second))
    }
}
