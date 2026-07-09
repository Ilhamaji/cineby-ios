import UIKit
import WebKit

class WebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    private var containerView: UIView!
    private var nativeRotateButton: UIButton!
    private var isFullscreen = false
    private var isLandscapeRotated = false

    private var webViewConstraints: [NSLayoutConstraint] = []
    private var rotateButtonConstraints: [NSLayoutConstraint] = []

    private var frameVideoVisibilities: [String: Bool] = [:]
    private var frameFullscreenStates: [String: Bool] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Cineby"

        setupWebView()
        setupNativeRotateButton()
        loadWebApp()
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
              Element.prototype.requestFullscreen = undefined;
              Element.prototype.webkitRequestFullscreen = undefined;
              Element.prototype.webkitRequestFullScreen = undefined;
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
            
            // Periodically check/force in case content is dynamic
            setInterval(function() {
                update();
                forcePlaysInline();
            }, 1000);

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

        // Initialize containerView
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.backgroundColor = .systemBackground
        containerView.addSubview(webView)

        webViewConstraints = [
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ]
        NSLayoutConstraint.activate(webViewConstraints)
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
        
        view.addSubview(nativeRotateButton)
        view.bringSubviewToFront(nativeRotateButton)
        
        updateRotateButtonConstraints(landscape: false)
    }

    private func updateRotateButtonConstraints(landscape: Bool) {
        NSLayoutConstraint.deactivate(rotateButtonConstraints)
        
        if landscape {
            // Physical bottom-left safe area of screen acts as the visual bottom-right in landscape mode
            rotateButtonConstraints = [
                nativeRotateButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                nativeRotateButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
                nativeRotateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
                nativeRotateButton.heightAnchor.constraint(equalToConstant: 40)
            ]
        } else {
            // Physical bottom-right safe area
            rotateButtonConstraints = [
                nativeRotateButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                nativeRotateButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
                nativeRotateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
                nativeRotateButton.heightAnchor.constraint(equalToConstant: 40)
            ]
        }
        NSLayoutConstraint.activate(rotateButtonConstraints)
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
        setOrientationVisual(!isLandscapeRotated)
    }

    func setOrientationVisual(_ landscape: Bool) {
        self.isLandscapeRotated = landscape
        
        UIView.animate(withDuration: 0.3) {
            if landscape {
                // Deactivate normal layout constraints
                NSLayoutConstraint.deactivate(self.webViewConstraints)
                self.webView.translatesAutoresizingMaskIntoConstraints = true
                
                // Apply a visual 90 degrees rotation
                self.webView.transform = CGAffineTransform(rotationAngle: .pi / 2)
                
                // Swap bounds width/height to make it occupy full screen horizontally
                let containerSize = self.containerView.bounds.size
                self.webView.bounds = CGRect(x: 0, y: 0, width: containerSize.height, height: containerSize.width)
                self.webView.center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                
                // Also rotate the rotate button itself so the text matches user horizontal holding
                self.nativeRotateButton.transform = CGAffineTransform(rotationAngle: .pi / 2)
            } else {
                // Reset transform
                self.webView.transform = .identity
                self.nativeRotateButton.transform = .identity
                
                // Re-enable Auto Layout constraints
                self.webView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate(self.webViewConstraints)
            }
            
            // Toggle bar and status bar appearances
            self.navigationController?.setNavigationBarHidden(landscape, animated: true)
            self.isFullscreen = landscape
            self.setNeedsStatusBarAppearanceUpdate()
            
            // Adjust button placement
            self.updateRotateButtonConstraints(landscape: landscape)
            
            self.view.layoutIfNeeded()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait // The view controller physically stays in portrait orientation
    }

    override var shouldAutorotate: Bool {
        return false // Do not rotate physically
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let frameKey = "\(message.frameInfo)"

        if message.name == "videoVisibility" {
            if let visible = message.body as? Bool {
                NSLog("videoVisibility [\(frameKey)] -> \(visible)")
                frameVideoVisibilities[frameKey] = visible
                
                let anyVideoVisible = frameVideoVisibilities.values.contains(true)
                DispatchQueue.main.async {
                    self.nativeRotateButton.isHidden = !anyVideoVisible
                }
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
                        self.setOrientationVisual(anyFullscreen)
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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "videoVisibility")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "fullscreenState")
    }
}
