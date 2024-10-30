import Foundation

public class WEO {
    private let cacheDirectory: URL?

    public init() {
        cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

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

            let updatedHTML = self.updateLinksToLocal(htmlString)
            completion(.success(updatedHTML))
        }.resume()
    }

    public func startTracking(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        deepHTMLScan(url: url) { result in
            switch result {
            case .success(let html):
                let links = self.extractLinks(from: html)
                self.trackLinks(links: links, completion: completion)
            case .failure(let error):
                completion(.failure(error))
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

    private func trackLinks(links: [URL], completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []

        for link in links {
            group.enter()
            deepHTMLScan(url: link) { result in
                switch result {
                case .success(let html):
                    let nestedLinks = self.extractLinks(from: html)
                    self.trackLinks(links: nestedLinks, completion: { _ in })
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "WeboffError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Erros durante o rastreamento: \(errors)"])))
            }
        }
    }

    public func mergeJSWithHTML(html: String, js: String) -> String {
        let script = "<script>\(js)</script>"
        return html.replacingOccurrences(of: "</body>", with: "\(script)</body>")
    }

    public func connectSavedPages(html: String) -> String {
        let pattern = "href=[\"'](.*?)[\"']"
        var connectedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let link = String(html[range])
                    if let cachedPage = retrieveFromCache(for: link) {
                        connectedHTML = connectedHTML.replacingOccurrences(of: link, with: "local://\(link)")
                    }
                }
            }
        }
        return connectedHTML
    }

    public func retrievePageResources(from html: String) -> [String] {
        let pattern = "(http[s]?://[^\"' ]+\\.(css|png|jpg|gif|js))"
        var resources: [String] = []
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 0), in: html) {
                    resources.append(String(html[range]))
                }
            }
        }
        return resources
    }

    private func retrieveFromCache(for url: String) -> String? {
        guard let cacheDir = cacheDirectory else { return nil }
        let filePath = cacheDir.appendingPathComponent(url.replacingOccurrences(of: "/", with: "_"))
        guard let data = try? Data(contentsOf: filePath) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func saveCSS(html: String) -> String {
        let pattern = "<link rel=[\"']stylesheet[\"'] href=[\"'](.*?)[\"'][^>]*>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let cssLink = String(html[range])
                    if let cssContent = downloadContent(from: cssLink) {
                        updatedHTML = updatedHTML.replacingOccurrences(of: cssLink, with: "local://\(cssLink)")
                    }
                }
            }
        }
        return updatedHTML
    }

    private func downloadContent(from url: String) -> String? {
        guard let dataURL = URL(string: url) else { return nil }
        return try? String(contentsOf: dataURL)
    }

    public func updateLinksToLocal(_ html: String) -> String {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let link = String(html[range])
                    updatedHTML = updatedHTML.replacingOccurrences(of: link, with: "local://\(link)")
                }
            }
        }
        return updatedHTML
    }

    public func saveMediaContent(html: String) -> [String] {
        let pattern = "<img[^>]+src=[\"']([^\"']+)\""
        var mediaResources = [String]()
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    mediaResources.append(String(html[range]))
                }
            }
        }
        return mediaResources
    }

    public func compressAndSaveContent(content: String) -> Data {
        let data = content.data(using: .utf8) ?? Data()
        return (try? (data as NSData).compressed(using: .lzfse)) ?? data
    }

    public func checkForUpdates(url: URL) -> Bool {
        guard let cacheDir = cacheDirectory else { return false }
        let filePath = cacheDir.appendingPathComponent(url.lastPathComponent)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path),
              let modificationDate = attributes[.modificationDate] as? Date else { return true }

        return Date().timeIntervalSince(modificationDate) > 86400
    }
}
