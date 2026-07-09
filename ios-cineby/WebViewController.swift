import UIKit
import WebKit

class WebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let contentController = WKUserContentController()
        contentController.add(self, name: "rotate")
        contentController.add(self, name: "native")

        // Inject JS: add Rotate + Fullscreen buttons and wire to native handlers
        let js = """
        (function() {
          try {
            if (!document.getElementById('nativeRotateBtn')){
              var btn = document.createElement('button');
              btn.id='nativeRotateBtn';
              btn.style.position='fixed';
              btn.style.bottom='20px';
              btn.style.right='20px';
              btn.style.zIndex=2147483647;
              btn.style.padding='10px 12px';
              btn.style.background='rgba(0,0,0,0.6)';
              btn.style.color='#fff';
              btn.style.border='none';
              btn.style.borderRadius='8px';
              btn.style.fontSize='14px';
              btn.innerText='Rotate';
              btn.onclick = function(){ window.webkit.messageHandlers.rotate.postMessage('toggle'); };
              document.body.appendChild(btn);
            }

            if (!document.getElementById('nativeFullBtn')){
              var fbtn = document.createElement('button');
              fbtn.id='nativeFullBtn';
              fbtn.style.position='fixed';
              fbtn.style.bottom='20px';
              fbtn.style.left='20px';
              fbtn.style.zIndex=2147483647;
              fbtn.style.padding='10px 12px';
              fbtn.style.background='rgba(0,0,0,0.6)';
              fbtn.style.color='#fff';
              fbtn.style.border='none';
              fbtn.style.borderRadius='8px';
              fbtn.style.fontSize='14px';
              fbtn.innerText='Fullscreen';
              fbtn.onclick = function(){ window.webkit.messageHandlers.native.postMessage('fullscreen'); };
              document.body.appendChild(fbtn);
            }

            // Try to add click listener on video elements to show our controls when user interacts
            document.addEventListener('click', function(){
              var v = document.querySelector('video');
              if(v){
                // ensure native button exists
                // nothing more for now
              }
            }, true);
          } catch(e) { }
        })();
        """

        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)

        if let url = URL(string: "https://cineby.at") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "rotate" {
            toggleOrientation()
            return
        }

        if message.name == "native" {
            if let body = message.body as? String, body == "fullscreen" {
                // ensure orientation first, then request fullscreen on the first video element
                setOrientation(.landscapeRight)
                let js = "(function(){var v=document.querySelector('video'); if(v){ if(v.requestFullscreen) v.requestFullscreen(); else if(v.webkitEnterFullScreen) v.webkitEnterFullScreen(); }})()"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    func toggleOrientation() {
        let device = UIDevice.current
        let isPortrait = device.orientation.isPortrait || device.orientation == .unknown
        if isPortrait {
            setOrientation(.landscapeRight)
        } else {
            setOrientation(.portrait)
        }
    }

    func setOrientation(_ orientation: UIInterfaceOrientation) {
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "rotate")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "native")
    }
}
