# WEO (Weboff)
![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) 
[![SPM](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)



## Author

Samuel Campos de Andrade

## License

WEO is available under the MIT license. See the LICENSE file for more info.

### Example Code

```swift
import SwiftUI
import WebKit
import WEO

struct ContentView: View {
    @State private var urlString: String = "https://www.google.com"
    @State private var webView: WKWebView!

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
                .padding()
            }
            .padding(.top)

            WebView(webView: $webView)
                .onAppear {
                    loadURL(urlString)
                }
        }
    }

    private func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))

        let weo = WEO()
        weo.startTracking(url: url) { result in
            switch result {
            case .success:
                print("Rastreamento concluído com sucesso.")
            case .failure(let error):
                print("Erro no rastreamento: \(error.localizedDescription)")
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        self.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {

    }
}

