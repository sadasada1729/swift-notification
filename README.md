# NotificationCore

A type-safe notification hub for model changes using Swift Concurrency. NotificationCore provides a strongly typed, async/await-friendly API built on `AsyncStream`, so you can publish and observe model updates without fragile string keys or legacy patterns.

## Features
- Type-safe notifications using generic `ObserverKey<T>`
- `AsyncStream`-based observation that integrates naturally with Swift Concurrency
- Global actor–backed state (`NotificationCoreActor`) for safe, serialized access
- Lightweight and dependency-free (no Combine, no Objective‑C runtime)
- Clear failure mode: attempts to send to an unregistered key trigger a precondition failure to catch misconfiguration early

## Swift Package Manager (SPM)

### Adding via Xcode
- Open your project in Xcode.
- Go to File > Add Package Dependencies…
- Enter the repository URL (replace with your repo URL) and choose a version rule (e.g., Up to Next Major).
- Select the `NotificationCore` product and add it to your target.

### Adding via Package.swift
```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "YourApp",
  platforms: [
    .iOS(.v18), .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/sadasada1729/swift-notification.git", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "YourApp",
      dependencies: [
        .product(name: "NotificationCore", package: "swift-notification")
      ]
    )
  ]
)
```
## Usage

``` Swift
 // Observe changes to the following model
 struct SamplePerson: Sendable, Equatable {
   let name: String
   let age: Int
 }

 // Register target entity
 extension NotificationCore.Name {
   static let person: ObserverKey<SamplePerson> = .init()
 }

 // Add an observer
 for await person in NotificationCore.addObserver(keyPath: \.person) {
   print(person)
 }

 // Post a change
 await NotificationCore.shared.send(keyPath: \.person, value: .init(name: "test1", age: 20))
```
