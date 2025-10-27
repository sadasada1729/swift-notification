import Foundation

func observe(content: @Sendable @escaping () async -> Bool, maxAttempts: Int = 100) async throws {
  let timer = AsyncStream { try? await Task.sleep(for: .seconds(0.5)) }
  var count: Int = 0
  for await _ in timer {
    if await content() { return }
    count += 1
    if count >= maxAttempts { throw TestObserverError() }
  }
}

struct TestObserverError: Error {}
