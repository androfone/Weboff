import Foundation

@available(iOS 13.0, *)
public class WEO {
    private let cacheDirectory: URL?
    private var totalDownloaded: Int64 = 0
    private let maxDownloadSize: Int64 = 3_380_000_000 // 3.38 GB
    private let slowDownThreshold: Int64 = 800_000_000 // 800 MB

    public init() {
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    @available(iOS 13.0, *)
    public func compilePage(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        deepHTMLScan(url: url) { result in
            switch result {
            case .success(let html):
                let links = self.extractLinks(from: html)
                
           var localHTML = html
                localHTML = self.saveCSS(localHTML)
                localHTML = self.saveJavaScript(localHTML)
                self.downloadImages(from: localHTML)
                self.downloadVideos(from: localHTML)

                   self.saveHTMLContent(url: url, html: localHTML)

                completion(.success(url))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @available(iOS 13.0, *)
    private func saveCSS(html: String) -> String {
        let pattern = "<link rel=[\"']stylesheet[\"'] href=[\"'](.*?)[\"'][^>]*>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let cssLink = String(html[range])
                    if let cssContent = downloadContent(from: cssLink) {
                        saveCSSContent(content: cssContent, for: cssLink)
                        updatedHTML = updatedHTML.replacingOccurrences(of: cssLink, with: "local://\(cssLink)")
                    }
                }
            }
        }
        return updatedHTML
    }

    @available(iOS 13.0, *)
    public func saveJavaScript(html: String) -> String {
        let pattern = "<script src=[\"'](.*?)[\"'][^>]*></script>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let jsLink = String(html[range])
                    if let jsContent = downloadContent(from: jsLink) {
                        saveJavaScriptContent(content: jsContent, for: jsLink)
                        updatedHTML = updatedHTML.replacingOccurrences(of: jsLink, with: "local://\(jsLink)")
                    }
                }
            }
        }
        return updatedHTML
    }

    private func downloadContent(from url: String) -> String? {
        guard let url = URL(string: url) else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var content: String?
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let html = String(data: data, encoding: .utf8) {
                content = html
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return content
    }

    private func saveCSSContent(content: String, for url: String) {
         guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.replacingOccurrences(of: "/", with: "_"))
        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {}
    }

    private func saveJavaScriptContent(content: String, for url: String) {
        guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.replacingOccurrences(of: "/", with: "_"))
        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {}
    }
    
    private func saveHTMLContent(url: URL, html: String) {
        guard let cacheDir = cacheDirectory else { return }
        let filePath = cacheDir.appendingPathComponent(url.lastPathComponent.replacingOccurrences(of: "/", with: "_"))
        do {
            try html.write(to: filePath, atomically: true, encoding: .utf8)
        } catch {
            print("Erro ao salvar conteúdo HTML: \(error)")
        }
    }

    private func downloadImages(from html: String) {
        let pattern = "src=[\"'](http[s]?://[^\"']+\\.(jpg|jpeg|png|gif))[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let imageLink = String(html[range])
                    _ = downloadContent(from: imageLink)
                }
            }
        }
    }

    private func downloadVideos(from html: String) {
        let pattern = "src=[\"'](http[s]?://[^\"']+\\.(mp4|mov|avi))[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let videoLink = String(html[range])
                    _ = downloadContent(from: videoLink)
                }
            }
        }
    }

    private func extractLinks(from html: String) -> [URL] {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        var links = [URL]()
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html),
                   let url = URL(string: String(html[range])) {
                    links.append(url)
                }
            }
        }
        return links
    }

    @available(iOS 13.0, *)
    public func deepHTMLScan(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard url.scheme == "https" else {
            completion(.failure(NSError(domain: "WeboffError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Apenas URLs HTTPS são permitidas."])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "WeboffError", code: 402, userInfo: [NSLocalizedDescriptionKey: "Erro ao converter dados para string."])))
                return
            }

            completion(.success(htmlString))
        }.resume()
    }
}
