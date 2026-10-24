import UIKit
import WebKit

/// The whole app: one full-screen web view that runs the game bundled in the app's "web" folder.
final class GameViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    /// The game's sky blue (the page background), also used for the launch screen. Info.plist keeps the app in the
    /// light appearance, so the page uses this same colour in Dark Mode too and nothing flashes at start-up.
    static let backgroundColor = UIColor(named: "LaunchBackground")
        ?? UIColor(red: 0xA7 / 255.0, green: 0xCB / 255.0, blue: 0xE6 / 255.0, alpha: 1)

    /// The page is served from selenaroller://localhost/. Saved progress (localStorage) belongs to this origin,
    /// so the scheme and host must never change after release, or players would lose their progress.
    static let scheme = "selenaroller"
    static let host = "localhost"
    private static let startURL = URL(string: "\(scheme)://\(host)/index.html")!

    /// Web Audio follows the silent switch and mixes with other apps, like the native audio session.
    private static let audioSessionScript =
        "if (navigator.audioSession) { try { navigator.audioSession.type = 'ambient'; } catch (e) {} }"

    #if DEBUG
    /// Debug builds only: uncaught script errors are shown on screen, so the CI simulator screenshot reveals them.
    private static let showErrorsScript = """
        addEventListener('error', function (e) {
          var p = document.createElement('pre');
          p.style.cssText = 'position:fixed;left:0;right:0;bottom:0;margin:0;padding:8px;z-index:2147483647;' +
            'font:12px/1.3 monospace;color:#f66;background:rgba(0,0,0,0.85);white-space:pre-wrap';
          p.textContent = e.message + ' (' + e.filename + ':' + e.lineno + ')';
          (document.body || document.documentElement).appendChild(p);
        });
        """
    #endif

    private lazy var webView: WKWebView = makeWebView()

    /// When the page's process last stopped, so a page that keeps stopping is not reloaded over and over.
    private var recentTerminations: [Date] = []
    /// True while the game waits for a tap, or for the player to come back to the app, before loading again.
    private var waitingToReload = false
    private lazy var retryTap: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(GameViewController.retryAfterTap))
        tap.isEnabled = false
        return tap
    }()

    override func loadView() {
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.addGestureRecognizer(retryTap)
        loadGame()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    // A swipe down from the top during play needs a second swipe to open Notification Center.
    // The bottom edge is left alone, so the home indicator can still hide itself.
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .top }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    private func loadGame() {
        webView.load(URLRequest(url: Self.startURL))
    }

    /// Pauses a level that is under way. SceneDelegate calls this when the app stops being the active app
    /// (Notification Centre, Control Centre, Siri, a call). The page stays visible then, so its own pause on
    /// visibilitychange does not run.
    func pauseGame() {
        webView.evaluateJavaScript("window.selenaPause && window.selenaPause();", completionHandler: nil)
    }

    /// Loads the game again if it stopped repeatedly and has been waiting. SceneDelegate calls this when the app
    /// becomes active; a tap on the screen does the same.
    func reloadIfWaiting() {
        guard waitingToReload else { return }
        waitingToReload = false
        retryTap.isEnabled = false
        loadGame()
    }

    @objc private func retryAfterTap() {
        reloadIfWaiting()
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        let webFolder = Bundle.main.bundleURL.appendingPathComponent("web", isDirectory: true)
        config.setURLSchemeHandler(BundleSchemeHandler(root: webFolder, host: Self.host), forURLScheme: Self.scheme)
        config.websiteDataStore = .default()                    // kept on the device between launches
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []    // the game's first tap starts its sound
        config.userContentController.addUserScript(WKUserScript(
            source: Self.audioSessionScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        #if DEBUG
        config.userContentController.addUserScript(WKUserScript(
            source: Self.showErrorsScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        #endif

        let webView = WKWebView(frame: .zero, configuration: config)
        // Not opaque, so the sky colour shows behind the page until its first paint (no white flash).
        webView.isOpaque = false
        webView.backgroundColor = Self.backgroundColor
        webView.scrollView.backgroundColor = Self.backgroundColor
        // A game screen, not a web page: no scrolling, bouncing or zooming.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // the page places itself with env(safe-area-inset-*)
        webView.scrollView.delegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        if scheme == Self.scheme || scheme == "about" {
            decisionHandler(.allow)
            return
        }
        // The game never shows outside pages; a link the player taps opens in Safari (or Mail) instead.
        if navigationAction.targetFrame?.isMainFrame ?? true {
            openOutside(url)
        }
        decisionHandler(.cancel)
    }

    /// iOS can end the page's process to free memory. Start the game again; progress is saved on the device.
    /// If it stops three times within a minute (for example very low memory on an older iPhone), wait for a tap
    /// or for the player to come back to the app before trying again, instead of reloading over and over.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let now = Date()
        recentTerminations = recentTerminations.filter { now.timeIntervalSince($0) < 60 }
        recentTerminations.append(now)
        if recentTerminations.count < 3 {
            loadGame()
        } else {
            waitingToReload = true
            retryTap.isEnabled = true
        }
    }

    // MARK: - WKUIDelegate

    /// Links that ask for a new window (target="_blank" or window.open) also open outside the app.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            openOutside(url)
        }
        return nil
    }

    private func openOutside(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), ["https", "http", "mailto"].contains(scheme) else { return }
        UIApplication.shared.open(url)
    }
}
