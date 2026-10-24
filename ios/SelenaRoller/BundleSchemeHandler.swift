import Foundation
import WebKit

/// Serves the files in the app's "web" folder at selenaroller://localhost/<path>.
/// Each request is answered in full before `start` returns, so WebKit can never stop a task
/// that is still being answered (calling a stopped task would crash the app).
@MainActor
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL
    private let host: String

    init(root: URL, host: String) {
        self.root = root
        self.host = host
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        guard let file = fileURL(for: url),
              let body = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            respond(to: urlSchemeTask, url: url, status: 404,
                    contentType: "text/plain; charset=utf-8", body: Data("Not found".utf8))
            return
        }
        respond(to: urlSchemeTask, url: url, status: 200, contentType: Self.contentType(for: file), body: body)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // Nothing to cancel: every request has already been answered in `start`.
    }

    /// The bundled file for a request, or nil when the request points anywhere outside the web folder.
    private func fileURL(for url: URL) -> URL? {
        guard url.host?.lowercased() == host else { return nil }
        var parts = url.path.split(separator: "/").map(String.init)
        if parts.isEmpty {
            parts = ["index.html"]
        }
        guard !parts.contains(where: { $0 == ".." || $0 == "." }) else { return nil }
        return parts.reduce(root) { $0.appendingPathComponent($1) }
    }

    private func respond(to task: any WKURLSchemeTask, url: URL, status: Int, contentType: String, body: Data) {
        let headers = [
            "Content-Type": contentType,
            "Content-Length": String(body.count),
            "Cache-Control": "no-cache"
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: headers) else {
            task.didFailWithError(URLError(.cannotParseResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    private static func contentType(for file: URL) -> String {
        switch file.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json", "map": return "application/json"
        case "webmanifest": return "application/manifest+json"
        case "txt": return "text/plain; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "aac": return "audio/aac"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "mp4": return "video/mp4"
        case "wasm": return "application/wasm"
        default: return "application/octet-stream"
        }
    }
}
