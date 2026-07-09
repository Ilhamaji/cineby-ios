#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR=""
for candidate in "$BASE_DIR/ios/App/App" "$BASE_DIR/ios/App"; do
  if [ -d "$candidate" ]; then
    TARGET_DIR="$candidate"
    break
  fi
done

if [ -z "$TARGET_DIR" ]; then
  echo "Error: iOS App target directory not found."
  echo "Checked: $BASE_DIR/ios/App/App and $BASE_DIR/ios/App"
  exit 1
fi

INFO_PLIST="$TARGET_DIR/Info.plist"
if [ -f "$INFO_PLIST" ]; then
  python3 <<PY
import plistlib
from pathlib import Path
p = Path(r"$INFO_PLIST")
data = plistlib.loads(p.read_bytes())
changed = False
screen_orient = ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
if data.get("UISupportedInterfaceOrientations") != screen_orient:
    data["UISupportedInterfaceOrientations"] = screen_orient
    changed = True
if data.get("UISupportedInterfaceOrientations~ipad") != screen_orient:
    data["UISupportedInterfaceOrientations~ipad"] = screen_orient
    changed = True
if data.get("UIRequiresFullScreen") is not True:
    data["UIRequiresFullScreen"] = True
    changed = True
if data.get("UIViewControllerBasedStatusBarAppearance") is not True:
    data["UIViewControllerBasedStatusBarAppearance"] = True
    changed = True
for key in ["UIMainStoryboardFile", "NSMainStoryboardFile", "UIMainStoryboardFile~ipad"]:
    if key in data:
        del data[key]
        changed = True
if changed:
    p.write_bytes(plistlib.dumps(data))
PY
fi

SRC_DIR="$BASE_DIR/../ios-cineby"
if [ ! -d "$SRC_DIR" ]; then
  echo "Error: Source directory $SRC_DIR not found."
  exit 1
fi

# Clean up any previously copied standalone files to prevent duplicate definitions in compile
rm -f "$TARGET_DIR/WebViewController.swift"
rm -f "$TARGET_DIR/OrientationNavigationController.swift"

echo "Merging source files into main delegate files..."

if [ -f "$TARGET_DIR/SceneDelegate.swift" ]; then
  echo "Target project uses SceneDelegate. Merging into SceneDelegate.swift..."
  
  # Copy clean SceneDelegate.swift template and append WebViewController and OrientationNavigationController
  cat > "$TARGET_DIR/SceneDelegate.swift" <<'EOF'
import UIKit
import WebKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let navigationController = OrientationNavigationController(rootViewController: WebViewController())
        window.rootViewController = navigationController
        self.window = window
        window.makeKeyAndVisible()
    }
}
EOF

  grep -v '^import ' "$SRC_DIR/WebViewController.swift" >> "$TARGET_DIR/SceneDelegate.swift"
  grep -v '^import ' "$SRC_DIR/OrientationNavigationController.swift" >> "$TARGET_DIR/SceneDelegate.swift"

  # Copy clean AppDelegate.swift template (no window logic needed since SceneDelegate is active)
  cat > "$TARGET_DIR/AppDelegate.swift" <<'EOF'
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return window?.rootViewController?.supportedInterfaceOrientations ?? .all
    }
}
EOF

else
  echo "Target project uses AppDelegate-only. Merging into AppDelegate.swift..."
  
  # Copy clean AppDelegate.swift template and append WebViewController and OrientationNavigationController
  cat > "$TARGET_DIR/AppDelegate.swift" <<'EOF'
import UIKit
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if window == nil {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window?.rootViewController = OrientationNavigationController(rootViewController: WebViewController())
        window?.makeKeyAndVisible()
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return window?.rootViewController?.supportedInterfaceOrientations ?? .all
    }
}
EOF

  grep -v '^import ' "$SRC_DIR/WebViewController.swift" >> "$TARGET_DIR/AppDelegate.swift"
  grep -v '^import ' "$SRC_DIR/OrientationNavigationController.swift" >> "$TARGET_DIR/AppDelegate.swift"
fi

echo "Successfully patched iOS project."
