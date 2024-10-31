# WEO (Weboff)
![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) 
[![SPM](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![WEO]([https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager](https://www.canva.com/design/DAGU_YiRiu4/4Sw-MjjIVjHmw3m7udkMgQ/edit?utm_content=DAGU_YiRiu4&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton))


## Author (WEO)

Samuel Campos de Andrade

## License (WEO)

WEO is available under the MIT license. See the LICENSE file for more info.

### Example Code (WEO)

```swift
import SwiftUI
import WebKit
import WEO

struct ContentView: View {
    @State private var urlString: String = "https://searx.be/search?q=a&language=all&time_range=&safesearch=0&categories=general"
    @State private var webView = WKWebView()
    private let weo = WEO()
    
    var body: some View {
        VStack {
            HStack {
                TextField("Digite a URL", text: $urlString, onCommit: {
                    loadURL(urlString)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                
                Button("Carregar") {
                    loadURL(urlString)
                }
                .foregroundColor(.blue)
                .padding()
            }
            
            WebView(webView: $webView)
                .onAppear {
                    loadURL(urlString)
                }
        }
        .padding()
    }
    
    private func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("URL inválida: \(urlString)")
            return
        }
        
        if let cachedHTML = weo.loadHTMLContent(url: url) {
            webView.loadHTMLString(cachedHTML, baseURL: url)
            print("Carregado a partir do cache.")
        } else {
            let request = URLRequest(url: url)
            webView.load(request)
            webView.navigationDelegate = WebViewDelegate(weo: weo, url: url)
        }
    }
}

class WebViewDelegate: NSObject, WKNavigationDelegate {
    var weo: WEO
    var url: URL
    
    init(weo: WEO, url: URL) {
        self.weo = weo
        self.url = url
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { (htmlContent, error) in
            if let html = htmlContent as? String {
                self.weo.saveHTMLContent(url: self.url, html: html)
                print("Conteúdo rastreado e salvo no cache.")
            } else if let error = error {
                print("Erro ao obter HTML: \(error.localizedDescription)")
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    @Binding var webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
