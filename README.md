# WEO (Weboff)
![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) 
[![SPM](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![WEO]([https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager](https://www.canva.com/design/DAGU_YiRiu4/4Sw-MjjIVjHmw3m7udkMgQ/edit?utm_content=DAGU_YiRiu4&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton))


## Author (WEO)

Samuel Campos de Andrade

## License (WEO)

WEO is available under the MIT license. See the LICENSE file for more info.

### Install (WEO)

```swift
import WEO
```

#### (https://github.com/SAMISsw/Weboff)

### Code for Example

```swift
import SwiftUI
import WebKit
import Network
import AVKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = BrowserViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                Text("WEO")
                    .font(.custom("Impact", size: 40))
                    .foregroundColor(.green)
                    .padding()

                HStack {
                    TextField("Digite a URL", text: $viewModel.urlString, onCommit: { viewModel.loadURL() })
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    Button(action: viewModel.goBack) {
                        Image(systemName: "arrow.left.circle.fill")
                    }
                    .disabled(!viewModel.canGoBack)

                    Button(action: viewModel.goForward) {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .disabled(!viewModel.canGoForward)
                }

                WebView(viewModel: viewModel)

                HStack {
                    Button(action: { viewModel.showSavedPages.toggle() }) {
                        Image(systemName: "star.fill")
                    }
                    Button(action: { viewModel.toggleTextMode() }) {
                        Image(systemName: "textformat")
                    }
                    Button(action: { viewModel.savePage() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Button(action: { viewModel.saveMedia() }) {
                        Image(systemName: "photo.fill")
                    }
                }
                .padding()

                if viewModel.showSavedPages {
                    SavedPagesView(viewModel: viewModel)
                }

                if let videoURL = viewModel.videoURL {
                    VideoPlayerView(url: videoURL)
                        .frame(height: 250)
                }
            }
            .background(Color.green)
            .onAppear {
                viewModel.loadDuckDuckGo()
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = context.coordinator
        return webview
    }

    func updateUIView(_ webview: WKWebView, context: Context) {
        if viewModel.isOnline {
            if let url = viewModel.currentURL {
                webview.load(URLRequest(url: url))
            }
        } else {
            webview.loadHTMLString(viewModel.offlineHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var viewModel: BrowserViewModel

        init(viewModel: BrowserViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { html, _ in
                if let htmlString = html as? String {
                    self.viewModel.saveCurrentPage(html: htmlString)
                }
            }
            viewModel.updateNavigationState(webView)
        }
    }
}

class BrowserViewModel: ObservableObject {
    @Published var currentURL: URL?
    @Published var showSavedPages = false
    @Published var urlString: String = ""
    @Published var offlineHTML: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isOnline: Bool = true
    @Published var textMode = false
    @Published var savedPages = [String: String]()
    @Published var videoURL: URL?
    @Published var mediaFiles = [String: String]()

    private var webView: WKWebView?
    private var monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isOnline = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }

    func loadURL() {
        if let url = URL(string: urlString) {
            currentURL = url
            if isOnline {
                loadURLRequest(URLRequest(url: url))
            } else {
                loadOfflineContent(for: url.absoluteString)
            }
        }
    }

    func loadDuckDuckGo() {
        urlString = "https://duckduckgo.com"
        loadURL()
    }

    func saveCurrentPage(html: String) {
        offlineHTML = replaceLinksWithOffline(html: html)
        UserDefaults.standard.set(offlineHTML, forKey: currentURL?.absoluteString ?? "")
        saveCSSJSFiles()
    }

    func replaceLinksWithOffline(html: String) -> String {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        return (try? NSRegularExpression(pattern: pattern))
            .map { regex in
                regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
                    .reduce(html) { result, match in
                        if let range = Range(match.range(at: 1), in: result) {
                            let url = String(result[range])
                            if let savedHTML = UserDefaults.standard.string(forKey: url) {
                                return result.replacingOccurrences(of: url, with: "data:text/html;base64,\(savedHTML.toBase64())")
                            }
                        }
                        return result
                    }
            } ?? html
    }

    func loadOfflineContent(for url: String) {
        offlineHTML = UserDefaults.standard.string(forKey: url) ?? "<h2>Sem conexão e sem cache</h2>"
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }

    func toggleTextMode() {
        textMode.toggle()
        offlineHTML = textMode ? offlineHTML.stripHTML() : UserDefaults.standard.string(forKey: currentURL?.absoluteString ?? "") ?? offlineHTML
    }

    func updateNavigationState(_ webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func savePage() {
        if let html = offlineHTML {
            savedPages[currentURL?.absoluteString ?? ""] = html
        }
    }

    func deletePage(url: String) {
        savedPages.removeValue(forKey: url)
    }

    func saveCSSJSFiles() {
        webView?.evaluateJavaScript("document.styleSheets") { (styleSheets, _) in
            if let styles = styleSheets as? [String] {
                for style in styles {
                    UserDefaults.standard.set(style, forKey: "CSS-\(self.currentURL?.absoluteString ?? "")")
                }
            }
        }

        webView?.evaluateJavaScript("document.scripts") { (scripts, _) in
            if let scriptsArray = scripts as? [String] {
                for script in scriptsArray {
                    UserDefaults.standard.set(script, forKey: "JS-\(self.currentURL?.absoluteString ?? "")")
                }
            }
        }
    }

    func saveMedia() {
        webView?.evaluateJavaScript("""
            var media = document.querySelectorAll('video, audio, img, source');
            var mediaArray = [];
            media.forEach(function(item) {
                if (item.src) mediaArray.push(item.src);
            });
            return mediaArray;
        """) { (media, _) in
            if let mediaArray = media as? [String] {
                self.downloadAndSaveMedia(mediaArray)
            }
        }
    }

    func downloadAndSaveMedia(_ mediaArray: [String]) {
        for media in mediaArray {
            if let url = URL(string: media) {
                downloadFile(from: url) { success in
                    if success {
                        let fileName = url.lastPathComponent
                        self.mediaFiles[fileName] = url.absoluteString
                        UserDefaults.standard.set(self.mediaFiles, forKey: "MediaFiles")
                    }
                }
            }
        }
    }

    func downloadFile(from url: URL, completion: @escaping (Bool) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            if let location = location {
                do {
                    let data = try Data(contentsOf: location)
                    let fileURL = self.getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
                    try data.write(to: fileURL)
                    completion(true)
                } catch {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
        task.resume()
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func expandCacheWithOfflineContent() {
        if let url = currentURL?.absoluteString {
            if let savedHTML = UserDefaults.standard.string(forKey: url) {
                offlineHTML = savedHTML
            }
        }
    }

    func deleteOfflineCache() {
        if let url = currentURL?.absoluteString {
            UserDefaults.standard.removeObject(forKey: url)
        }
    }
}

extension String {
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

    func stripHTML() -> String {
        let regex = try! NSRegularExpression(pattern: "<.*?>", options: [])
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
    }
}

```
