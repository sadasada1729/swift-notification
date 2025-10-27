import NotificationCore
import Testing

struct SamplePerson: Sendable, Equatable {
  let name: String
  let age: Int
}

extension NotificationCore.Name {
  static let person: ObserverKey<SamplePerson> = .init()
}

@globalActor
public struct TestActor {
  public actor ActorType {}
  public static let shared: ActorType = ActorType()
}

@TestActor
class NotificationCoreTests {
  var person1: SamplePerson!
  var person2: SamplePerson!
  var person3: SamplePerson!

  func setObserver() {
    Task {
      for await person in NotificationCore.addObserver(keyPath: \.person ) {
        Task { @TestActor [weak self] in
          self?.person1 = person
        }
      }
    }
    Task {
      for await person in NotificationCore.addObserver(keyPath: \.person ) {
        Task { @TestActor [weak self] in
          self?.person2 = person
        }
      }
    }
    Task {
      for await person in NotificationCore.addObserver(keyPath: \.person ) {
        Task { @TestActor [weak self] in
          self?.person3 = person
        }
      }
    }
  }

  @Test("notification test")
  func test() async throws {
    setObserver()
    try? await Task.sleep(nanoseconds: 100_000_000)
    await NotificationCore.shared.send(keyPath: \.person , value: .init(name: "test1", age: 20))
    try await observe { [unowned self] in await self.person1.name == "test1" }
    #expect(person1 == SamplePerson(name: "test1", age: 20))
    #expect(person2 == SamplePerson(name: "test1", age: 20))
    #expect(person3 == SamplePerson(name: "test1", age: 20))
    await NotificationCore.shared.send(keyPath: \.person, value: .init(name: "test2", age: 30))
    try await observe { [unowned self] in await self.person1.name == "test2" }
    #expect(person1 == SamplePerson(name: "test2", age: 30))
    #expect(person2 == SamplePerson(name: "test2", age: 30))
    #expect(person3 == SamplePerson(name: "test2", age: 30))
  }
}

