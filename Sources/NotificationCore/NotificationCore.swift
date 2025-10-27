/// Modelの変更を通知する
/// SwiftのNotificationCenterは型安全ではなくEntityの変更を通知したい時でもハードコーディングする必要があった
/// これに対応したのが今回作成したNotificationCoreで, 従来のObjcやCombineではなくAsyncStreamを用いて通知する.
/// 以下に使用例を示す

/**
 // 以下のstructを監視する
 struct SamplePerson: Sendable, Equatable {
   let name: String
   let age: Int
 }

 extension NotificationCore.Name {
   static let person: ObserverKey<SamplePerson> = .init()
 }

 // observerを追加
 for await person in NotificationCore.addObserver(keyPath: \.person ) {
    print(person)
 }

 // 変更を通知
 await NotificationCore.shared.send(keyPath: \.person , value: .init(name: "test1", age: 20))
**/

extension KeyPath: @unchecked @retroactive Sendable {}

@globalActor
public struct NotificationCoreActor {
  public actor ActorType {}
  public static let shared: ActorType = ActorType()
}

@NotificationCoreActor
public class NotificationCore {
  public static let shared = NotificationCore()
  private var observerStorage: [ObservableModelID: [Any]] = [:]
  private init() {}

  /// Modelの変更を監視する
  /// - Parameter key: NotificationCore.Name.key
  /// - Returns: AsyncStreamで変更を通知する
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

  /// Modelの変更を通知する
  /// - Parameters:
  ///   - key: NotificationCore.Name.key
  ///   - value: 通知する値
  public func send<Model: Sendable>(keyPath: KeyPath<Name.Type, ObserverKey<Model>>, value: Model) {
    let key = Self.Name.self[keyPath: keyPath]
    Sender<Model>(key: key).send(value: value)
  }
}

// MARK: - NotificationCore.Name
public extension NotificationCore {
  struct Name {}
}

// MARK: - Private Logic
private extension NotificationCore {
  /// observerを破棄する
  /// - Parameter observerID: `observeItems`で取得したID
  func removeObserver(observerID: ObservableModelID) {
    observerStorage.removeValue(forKey: observerID)
  }
}

// MARK: - Internal
internal extension NotificationCore {
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
