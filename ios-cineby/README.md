# Cineby iOS — Minimal WKWebView App

Quick instructions for running this demo in Xcode:

1. Open Xcode → Create a new project → App (iOS).
2. Choose the `UIKit` interface and `UIKit App Delegate` lifecycle.
3. Delete Main.storyboard (optional) and configure `SceneDelegate` to make `WebViewController` the root.
4. Copy `AppDelegate.swift`, `SceneDelegate.swift`, and `WebViewController.swift` from this folder into your Xcode target.
5. Ensure the Deployment Target is iOS 13+.
6. Build & Run on a simulator or a physical device. For full orientation testing, use a physical device.

Notes:

- This app injects a `Rotate` button into the web page (`cineby.at`). The button sends a message to the native side to toggle orientation between portrait and landscape.
- You might need to adjust the JS selectors if the site changes its DOM structure.
