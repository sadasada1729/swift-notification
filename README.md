# NotificationCore

A type-safe notification hub for model changes using Swift Concurrency. NotificationCore provides a strongly typed, async/await-friendly API built on `AsyncStream`, so you can publish and observe model updates without fragile string keys or legacy patterns.

## Features
- Type-safe notifications using generic `ObserverKey<T>`
- `AsyncStream`-based observation that integrates naturally with Swift Concurrency
- Global actor–backed state (`NotificationCoreActor`) for safe, serialized access
- Lightweight and dependency-free (no Combine, no Objective‑C runtime)
- Clear failure mode: attempts to send to an unregistered key trigger a precondition failure to catch misconfiguration early

## Usage

### 1) Define a model
```swift
struct SamplePerson: Sendable, Equatable {
  let name: String
  let age: Int
}
