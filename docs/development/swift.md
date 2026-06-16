# Swift Apps

PebbleOS can run watch apps written in [Embedded Swift](https://www.swift.org/blog/embedded-swift-examples/).
Swift compiles to a native ARM app that links against the same jump-table SDK as
C apps, so no firmware support is needed beyond the build tooling. A small
SwiftUI-like layer, **PebbleUI**, ships with the SDK.

## Creating a Swift app

A Swift project sets `projectType` to `swift` in its `package.json` and puts its
sources under `src/swift/`:

```json
{ "pebble": { "projectType": "swift", "targetPlatforms": ["emery"] } }
```

`PebbleUI` is provided by the SDK and compiled together with the app — there is
no per-project copy. A whole app can be:

```swift
@main
struct MyWatchApp: PebbleApp {
  var body: some PebbleScene {
    Window {
      VStack(spacing: 8) {
        Text("Hello, Swift")
        HStack { Text("Pebble"); Text("Time 2") }
      }
    }
  }
}
```

`@main` provides the `main` entry point the loader expects (no C shim).

## PebbleUI

- **Scenes**: `Window { ... }`. `Window.push()` navigates to another window from
  a click handler; the back button pops it.
- **Views**: `Text`, `Image(UInt32(RESOURCE_ID_X), height:)`, `Spacer(_:)`.
- **Layout**: `VStack(spacing:)`, `HStack(spacing:)` (divides width equally),
  `Padding(_:)`.
- **State**: `State<Value>` updates bound `Label { "\(state.value)" }` views in
  place when mutated.
- **Input**: pass a `ClickConfigProvider` to `Window(clicks:)` and subscribe with
  `window_single_click_subscribe`. Handlers are C function pointers, so use
  non-capturing closures and module-global state.

## Constraints

Embedded Swift and the app ABI impose some limits:

- Apps are compiled soft-float for the cortex-m3 app ABI. Relocations must stay
  in `.got`/`.rel.data`; the build fails if an app emits an absolute relocation
  elsewhere.
- No existentials (`any`) or runtime casts. View composition is fully generic
  (fixed-arity result-builder overloads), which is why `PebbleUI` uses `Pair`
  rather than a variadic container.
- Heap types (classes, `Array`, `String`) work via an SDK runtime shim. Avoid
  `Set`/`Dictionary` and other hashing in shipped code — Swift's hash seeding
  pulls in entropy syscalls the app SDK does not provide.
- `Label` truncates to 64 bytes. The layout engine is intentionally simple:
  `HStack` rows are one line tall, `Padding` lays its content out vertically, and
  spacing is applied between every `Pair` element.
