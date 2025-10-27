/// A type-safe notification hub for model changes.
///
/// Swift's `NotificationCenter` isn't type-safe and often requires hard-coded string keys
/// even when notifying changes to specific entities. `NotificationCore` addresses this by
/// providing a strongly typed, async/await-friendly API built on `AsyncStream`, rather than
/// legacy Objective‑C patterns or Combine.
///
/// The following example demonstrates how to observe and send updates:
/**
 // Observe changes to the following model
 struct SamplePerson: Sendable, Equatable {
   let name: String
   let age: Int
 }

 extension NotificationCore.Name {
   static let person: ObserverKey<SamplePerson> = .init()
 }

 // Add an observer
 for await person in NotificationCore.addObserver(keyPath: \.person) {
   print(person)
 }

 // Post a change
 await NotificationCore.shared.send(keyPath: \.person, value: .init(name: "test1", age: 20))
**/

extension KeyPath: @unchecked @retroactive Sendable {}

/// A global actor that serializes access to `NotificationCore`'s shared state.
@globalActor
public struct NotificationCoreActor {
  public actor ActorType {}
  public static let shared: ActorType = ActorType()
}

/// A strongly typed notification center that publishes model changes via `AsyncStream`.
@NotificationCoreActor
public class NotificationCore {
  public static let shared = NotificationCore()
  private var observerStorage: [ObservableModelID: [Any]] = [:]
  private init() {}

  /// Subscribes to updates for the specified key.
  /// - Parameter keyPath: A key path to an `ObserverKey` defined on `NotificationCore.Name`.
  /// - Returns: An `AsyncStream` that yields values whenever a matching update is posted.
  public nonisolated static func addObserver<Model: Sendable>(keyPath: KeyPath<Name.Type, ObserverKey<Model>>) -> AsyncStream<Model> {
    AsyncStream { continuation in
      let key = Self.Name.self[keyPath: keyPath]
      Task { @NotificationCoreActor in
        Observer<Model>(key: key) { item in
          continuation.yield(item)
        }
        .register()
      }
      continuation.onTermination = { _ in
        Task { @NotificationCoreActor in
          Self.shared.removeObserver(observerID: key.id)
        }
      }
    }
  }

  /// Posts an update for the specified key.
  /// - Parameters:
  ///   - keyPath: A key path to an `ObserverKey` defined on `NotificationCore.Name`.
  ///   - value: The value to deliver to observers.
  public func send<Model: Sendable>(keyPath: KeyPath<Name.Type, ObserverKey<Model>>, value: Model) {
    let key = Self.Name.self[keyPath: keyPath]
    Sender<Model>(key: key).send(value: value)
  }
}

// MARK: - NotificationCore.Name
public extension NotificationCore {
  /// A namespace for declaring typed observer keys.
  struct Name {}
}

// MARK: - Private Logic
private extension NotificationCore {
  /// Removes all observers associated with the given identifier.
  /// - Parameter observerID: The identifier returned from registration.
  func removeObserver(observerID: ObservableModelID) {
    observerStorage.removeValue(forKey: observerID)
  }
}

// MARK: - Internal
internal extension NotificationCore {
  /// Stores a typed callback and registers it under a specific observer key.
  @NotificationCoreActor
  struct Observer<Model: Sendable> {
    internal let key: ObserverKey<Model>
    internal var observer: @Sendable (_ item: Model) -> Void
    internal init(key: ObserverKey<Model>, observer: @Sendable @escaping (_: Model) -> Void) {
      self.key = key
      self.observer = observer
    }
    internal func register() {
      NotificationCore.shared.observerStorage[key.id, default: []].append(self)
    }
  }

  /// Delivers values to observers registered under a specific key and validates key usage.
  @NotificationCoreActor
  struct Sender<Model: Sendable> {
    internal let key: ObserverKey<Model>
    internal init(key: ObserverKey<Model>) {
      self.key = key
      validateKey(key: key)
    }
    internal func send(value: Model) {
      for case let observer as Observer<Model> in NotificationCore.shared.observerStorage[key.id, default: []] {
        observer.observer(value)
      }
    }
    internal func validateKey(key: ObserverKey<Model>) {
      if NotificationCore.shared.observerStorage.keys.contains(where: { $0 == key.id }) { return }
      preconditionFailure("{ key = \(key) } is not registered. Add key in NotificationCore.Name extension.")
    }
  }
}
