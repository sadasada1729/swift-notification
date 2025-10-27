import Foundation

internal typealias ObservableModelID = UUID

public struct ObserverKey<Model: Sendable>: Sendable {
  internal let id: ObservableModelID = .init()
  internal let model: Model.Type
  public init() {
    self.model = Model.self
  }
}
