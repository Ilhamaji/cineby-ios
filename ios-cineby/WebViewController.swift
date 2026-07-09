import UIKit
import WebKit

class WebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    private var rotationLocked: Bool = false
    private var lockedOrientation: UIInterfaceOrientationMask = .all

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Cineby"

        setupWebView()
        loadWebApp()
    }

    func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "rotate")

        let js = """
        (function() {
          try {
            var btn = document.getElementById('nativeRotateBtn');
            if (!btn) {
              btn = document.createElement('button');
              btn.id = 'nativeRotateBtn';
              btn.style.position = 'fixed';
              btn.style.bottom = '20px';
              btn.style.right = '20px';
              btn.style.zIndex = 2147483647;
              btn.style.padding = '10px 12px';
              btn.style.background = 'rgba(0,0,0,0.6)';
              btn.style.color = '#fff';
              btn.style.border = 'none';
              btn.style.borderRadius = '8px';
              btn.style.fontSize = '14px';
              btn.style.cursor = 'pointer';
              btn.style.display = 'none';
              btn.innerText = 'Rotate';
              btn.onclick = function() { window.webkit.messageHandlers.rotate.postMessage('toggle'); };
              document.body.appendChild(btn);
            }

            function hasVisibleVideo() {
              var videos = Array.from(document.querySelectorAll('video'));
              return videos.some(function(video) {
                var rect = video.getBoundingClientRect();
                var style = window.getComputedStyle(video);
                return rect.width > 100 && rect.height > 50 && rect.bottom > 0 && rect.right > 0 && rect.top < window.innerHeight && rect.left < window.innerWidth && style.visibility !== 'hidden' && style.display !== 'none';
              });
            }

            function updateButton() {
              btn.style.display = hasVisibleVideo() ? 'block' : 'none';
            }

            var observer = new MutationObserver(updateButton);
            observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
            document.addEventListener('fullscreenchange', updateButton);
            document.addEventListener('webkitfullscreenchange', updateButton);
            updateButton();
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
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
    }

    func loadWebApp() {
        if let url = URL(string: "https://cineby.at") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc func toggleRotate() {
        toggleOrientation()
    }

    func toggleOrientation() {
        let device = UIDevice.current
        let isPortrait = device.orientation.isPortrait || device.orientation == .unknown
        if isPortrait {
            setOrientation(.landscapeRight)
            if rotationLocked {
                lockedOrientation = .landscape
            }
        } else {
            setOrientation(.portrait)
            if rotationLocked {
                lockedOrientation = .portrait
            }
        }
    }

    func setOrientation(_ orientation: UIInterfaceOrientation) {
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return lockedOrientation
    }

    override var shouldAutorotate: Bool {
        return true
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "rotate" {
            toggleOrientation()
        }
    }

    // MARK: WKNavigationDelegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "rotate")
    }
}
