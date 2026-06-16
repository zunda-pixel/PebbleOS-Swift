// SPDX-License-Identifier: Apache-2.0
//
// A Pebble watch app written declaratively in Embedded Swift. @main provides
// the `main` entry symbol the app loader expects (no C shim needed).

@main
struct MyWatchApp: PebbleApp {
  var body: some PebbleScene {
    Window {
      Text("Hello, Swift")
      Text("Pebble Time 2")
    }
  }
}
