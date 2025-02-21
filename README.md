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
import WEO
import WebKit
struct ContentView: View {
    @State private var urlText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var htmlContent: String? = nil
    @State private var webOff = WEO()

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter URL", text: $urlText)
                        .padding()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Go") {
                        loadWebsite(urlString: urlText)
                    }
                    .padding()
                }
                .padding()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                if let htmlContent = htmlContent {
                    WebView(htmlContent: htmlContent)
                        .padding()
                }
            }
            .navigationBarTitle("WEO")
        }
    }

    func loadWebsite(urlString: String) {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "URL inválido"
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        webOff.deepHTMLScan(url: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let html):
                    self.htmlContent = html
                case .failure(let error):
                    self.errorMessage = "Erro ao carregar site: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }
}

struct WebView: View {
    var htmlContent: String

    var body: some View {
        WebViewRepresentable(htmlContent: htmlContent)
            .edgesIgnoringSafeArea(.all)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    var htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
```
