// A Pebble watch app written declaratively in Embedded Swift. @main provides
// the `main` entry symbol the app loader expects (no C shim needed). PebbleUI
// is provided by the SDK, so this project contains only app code.

@main
struct MyWatchApp: PebbleApp {
  var body: some PebbleScene {
    Window {
      VStack(spacing: 8) {
        Text("Hello, Swift")
        HStack(spacing: 6) {
          Text("Pebble")
          Text("Time 2")
        }
      }
    }
  }
}
