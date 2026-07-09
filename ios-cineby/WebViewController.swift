import UIKit
import WebKit

class WebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    private var nativeRotateButton: UIButton!
    private var isFullscreen = false
    private var targetOrientation: UIInterfaceOrientationMask = .all

    private var frameVideoVisibilities: [String: Bool] = [:]
    private var frameFullscreenStates: [String: Bool] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Cineby"

        setupWebView()
        setupNativeRotateButton()
        loadWebApp()
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: UIWindow.didBecomeKeyNotification, object: nil)
    }

    func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "videoVisibility")
        contentController.add(self, name: "fullscreenState")

        let js = """
        (function() {
          try {
            // Disable native WebKit fullscreen player on iPhone to force HTML5 player fullscreen
            try {
              HTMLVideoElement.prototype.webkitEnterFullscreen = undefined;
              HTMLVideoElement.prototype.webkitEnterFullScreen = undefined;
              HTMLVideoElement.prototype.webkitRequestFullscreen = undefined;
              HTMLVideoElement.prototype.webkitRequestFullScreen = undefined;
            } catch (e) {}

            function hasVisibleVideo() {
              var videos = Array.from(document.querySelectorAll('video'));
              return videos.some(function(video) {
                var rect = video.getBoundingClientRect();
                var style = window.getComputedStyle(video);
                return rect.width > 100 && rect.height > 50 &&
                  rect.bottom > 0 && rect.right > 0 &&
                  rect.top < window.innerHeight && rect.left < window.innerWidth &&
                  style.visibility !== 'hidden' && style.display !== 'none';
              });
            }

            function forcePlaysInline() {
              var videos = Array.from(document.querySelectorAll('video'));
              videos.forEach(function(video) {
                if (!video.hasAttribute('playsinline')) {
                  video.setAttribute('playsinline', 'true');
                  video.setAttribute('webkit-playsinline', 'true');
                }
              });
            }

            var last = null;
            function update() {
                var v = hasVisibleVideo();
                if (v !== last) {
                    try { window.webkit.messageHandlers.videoVisibility.postMessage(v); } catch(e){}
                    last = v;
                }
            }

            var observer = new MutationObserver(function() {
                update();
                forcePlaysInline();
            });
            observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
            window.addEventListener('resize', update);
            window.addEventListener('scroll', update);

            function postFullscreen() {
                var fs = !!(document.fullscreenElement || document.webkitFullscreenElement || document.webkitIsFullScreen);
                try { window.webkit.messageHandlers.fullscreenState.postMessage(fs); } catch(e){}
            }
            document.addEventListener('fullscreenchange', function(){ update(); postFullscreen(); });
            document.addEventListener('webkitfullscreenchange', function(){ update(); postFullscreen(); });
            
            update();
            forcePlaysInline();
          } catch (e) { }
        })();
        """

        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.backgroundColor = .systemBackground
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func setupNativeRotateButton() {
        nativeRotateButton = UIButton(type: .system)
        nativeRotateButton.setTitle("Rotate", for: .normal)
        nativeRotateButton.setTitleColor(.white, for: .normal)
        nativeRotateButton.backgroundColor = UIColor(white: 0, alpha: 0.6)
        nativeRotateButton.layer.cornerRadius = 8
        nativeRotateButton.translatesAutoresizingMaskIntoConstraints = false
        nativeRotateButton.isHidden = true
        nativeRotateButton.addTarget(self, action: #selector(nativeRotateTapped), for: .touchUpInside)
    }

    func loadWebApp() {
        if let url = URL(string: "https://cineby.at") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc func nativeRotateTapped() {
        NSLog("nativeRotateTapped called")
        toggleOrientation()
    }

    func toggleOrientation() {
        let isPortrait: Bool
        if let scene = view.window?.windowScene {
            isPortrait = scene.interfaceOrientation.isPortrait
        } else {
            let device = UIDevice.current
            isPortrait = device.orientation.isPortrait || device.orientation == .unknown
        }
        NSLog("toggleOrientation: isPortrait=\(isPortrait)")
        if isPortrait {
            setOrientation(.landscapeRight)
        } else {
            setOrientation(.portrait)
        }
    }

    private func getActiveWindowScene() -> UIWindowScene? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        }
        return nil
    }

    func setOrientation(_ orientation: UIInterfaceOrientation) {
        let mask: UIInterfaceOrientationMask
        switch orientation {
        case .portrait:
            mask = .portrait
        case .landscapeLeft:
            mask = .landscapeLeft
        case .landscapeRight:
            mask = .landscapeRight
        case .portraitUpsideDown:
            mask = .portraitUpsideDown
        default:
            mask = .all
        }
        
        self.targetOrientation = mask
        
        if #available(iOS 16.0, *) {
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
            self.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            
            let scene = self.getActiveWindowScene() ?? self.view.window?.windowScene
            guard let windowScene = scene else { return }
            
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                NSLog("Failed to change orientation: \(error.localizedDescription)")
            }
        } else {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return targetOrientation
    }

    override var shouldAutorotate: Bool {
        return true
    }

    private func getTopWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            let activeScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            return activeScene?.windows.last ?? UIApplication.shared.windows.last
        } else {
            return UIApplication.shared.windows.last
        }
    }

    func updateRotateButtonVisibility(visible: Bool) {
        DispatchQueue.main.async {
            self.nativeRotateButton.isHidden = !visible
            if visible {
                if let topWindow = self.getTopWindow() {
                    if self.nativeRotateButton.superview != topWindow {
                        self.nativeRotateButton.removeFromSuperview()
                        topWindow.addSubview(self.nativeRotateButton)
                    }
                    
                    NSLayoutConstraint.deactivate(self.nativeRotateButton.constraints)
                    self.nativeRotateButton.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        self.nativeRotateButton.trailingAnchor.constraint(equalTo: topWindow.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                        self.nativeRotateButton.bottomAnchor.constraint(equalTo: topWindow.safeAreaLayoutGuide.bottomAnchor, constant: -16),
                        self.nativeRotateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
                        self.nativeRotateButton.heightAnchor.constraint(equalToConstant: 40)
                    ])
                    topWindow.bringSubviewToFront(self.nativeRotateButton)
                }
            } else {
                self.nativeRotateButton.removeFromSuperview()
            }
        }
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        if !nativeRotateButton.isHidden {
            updateRotateButtonVisibility(visible: true)
        }
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let frameKey = "\(message.frameInfo)"

        if message.name == "videoVisibility" {
            if let visible = message.body as? Bool {
                NSLog("videoVisibility [\(frameKey)] -> \(visible)")
                frameVideoVisibilities[frameKey] = visible
                
                let anyVideoVisible = frameVideoVisibilities.values.contains(true)
                updateRotateButtonVisibility(visible: anyVideoVisible)
            }
            return
        }

        if message.name == "fullscreenState" {
            if let fs = message.body as? Bool {
                NSLog("fullscreenState [\(frameKey)] -> \(fs)")
                frameFullscreenStates[frameKey] = fs
                
                let anyFullscreen = frameFullscreenStates.values.contains(true)
                
                if self.isFullscreen != anyFullscreen {
                    DispatchQueue.main.async {
                        self.isFullscreen = anyFullscreen
                        self.navigationController?.setNavigationBarHidden(anyFullscreen, animated: true)
                        self.setNeedsStatusBarAppearanceUpdate()
                        self.updateRotateButtonVisibility(visible: !self.nativeRotateButton.isHidden)
                        
                        if !anyFullscreen {
                            self.setOrientation(.portrait)
                            self.targetOrientation = .all
                            if #available(iOS 16.0, *) {
                                self.setNeedsUpdateOfSupportedInterfaceOrientations()
                                self.navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                            }
                        }
                    }
                }
            }
            return
        }
    }

    override var prefersStatusBarHidden: Bool {
        return isFullscreen
    }

    private func isTrustedURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host.lowercased().contains("cineby")
    }

    // MARK: WKNavigationDelegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                if isTrustedURL(url) {
                    webView.load(navigationAction.request)
                } else {
                    NSLog("Blocked popup navigation to untrusted site: \(url.absoluteString)")
                }
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                if isTrustedURL(url) {
                    webView.load(navigationAction.request)
                } else {
                    NSLog("Blocked popup window creation to untrusted site: \(url.absoluteString)")
                }
            }
        }
        return nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "videoVisibility")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "fullscreenState")
    }
}
