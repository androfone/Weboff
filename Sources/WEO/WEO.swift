import Foundation

public class WEO {
    private let storage: Storage<String, String>?
    
    public init() {
        let diskConfig = DiskConfig(name: "WeboffCache", expiry: .date(Date().addingTimeInterval(60*60*24*7)))
        let memoryConfig = MemoryConfig(expiry: .never)
        self.storage = try? Storage<String, String>(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: TransformerFactory.forCodable(ofType: String.self))
    }
    
    public func deepHTMLScan(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard url.scheme == "https" else {
            completion(.failure(NSError(domain: "WeboffError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Apenas URLs HTTPS são permitidas."])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(error!))
                return
            }
            
            let htmlString = String(data: data, encoding: .utf8) ?? ""
            let updatedHTML = self.updateLinksToLocal(htmlString)
            completion(.success(updatedHTML))
        }.resume()
    }
    
    public func mergeJSWithHTML(html: String, js: String) -> String {
        return html.replacingOccurrences(of: "</body>", with: "<script>\(js)</script></body>")
    }
    
    public func connectSavedPages(html: String) -> String {
        let pattern = "href=[\"'](.*?)[\"']"
        var connectedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                let linkRange = match.range(at: 1)
                if let swiftRange = Range(linkRange, in: html) {
                    let link = String(html[swiftRange])
                    if let cachedPage = try? storage?.entry(forKey: link).object {
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
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 0), in: html) {
                    let resource = String(html[range])
                    resources.append(resource)
                }
            }
        }
        return resources
    }
    
    public func saveCSS(html: String) -> String {
        let pattern = "<link rel=[\"']stylesheet[\"'] href=[\"'](.*?)[\"'][^>]*>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                let linkRange = match.range(at: 1)
                if let swiftRange = Range(linkRange, in: html) {
                    let cssLink = String(html[swiftRange])
                    if let cssData = try? Data(contentsOf: URL(string: cssLink)!) {
                        let cssString = String(data: cssData, encoding: .utf8) ?? ""
                        updatedHTML = updatedHTML.replacingOccurrences(of: cssLink, with: "local://\(cssLink)")
                    }
                }
            }
        }
        return updatedHTML
    }
    
    public func processInlineScripts(html: String) -> String {
        let pattern = "<script.*?>(.*?)</script>"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                let scriptRange = match.range(at: 1)
                if let swiftRange = Range(scriptRange, in: html) {
                    let inlineScript = String(html[swiftRange])
                }
            }
        }
        return updatedHTML
    }
    
    public func updateLinksToLocal(_ html: String) -> String {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                let linkRange = match.range(at: 1)
                if let swiftRange = Range(linkRange, in: html) {
                    let link = String(html[swiftRange])
                    updatedHTML = updatedHTML.replacingOccurrences(of: link, with: "local://\(link)")
                }
            }
        }
        return updatedHTML
    }
    
    public func checkAndConnectLinks(html: String) -> String {
        let updatedHTML = connectSavedPages(html: html)
        return updatedHTML
    }
    
    public func saveMediaContent(html: String) -> [String] {
        let pattern = "<img[^>]+src=[\"']([^\"']+)\""
        var mediaResources = [String]()
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    mediaResources.append(String(html[range]))
                }
            }
        }
        return mediaResources
    }
    
    public func compressAndSaveContent(content: String) -> Data {
        guard let data = content.data(using: .utf8) else { return Data() }
        return (try? (data as NSData).compressed(using: .lzfse)) ?? data
    }
    
    public func generateSavedPagesIndex() -> String {
        var index = "<html><body><h1>Índice de Páginas Salvas</h1><ul>"
        storage?.allKeys().forEach { key in
            index += "<li><a href=\"local://\(key)\">\(key)</a></li>"
        }
        index += "</ul></body></html>"
        return index
    }
    
    public func checkForUpdates(url: URL) -> Bool {
        let lastUpdate = storage?.entry(forKey: url.absoluteString)?.meta?.createdAt
        let currentTime = Date()
        return lastUpdate.map { currentTime.timeIntervalSince($0) > 86400 } ?? false
    }
    
    public func retrieveJSONContent(from url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    public func createOfflineNavigationHistory() -> [String] {
        return storage?.allKeys() ?? []
    }
    
    public func captureAndSavePageJS(html: String) -> String {
        let pattern = "<script[^>]*src=[\"'](http[s]?://[^\"']+\\.js)[\"']"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let jsLink = String(html[range])
                    updatedHTML = updatedHTML.replacingOccurrences(of: jsLink, with: "local://\(jsLink)")
                }
            }
        }
        return updatedHTML
    }
    
    public func downloadAndLinkCSSResources(html: String) -> String {
        let pattern = "<link[^>]+href=[\"']([^\"']+\\.css)[\"']"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let cssLink = String(html[range])
                    updatedHTML = updatedHTML.replacingOccurrences(of: cssLink, with: "local://\(cssLink)")
                }
            }
        }
        return updatedHTML
    }
    
    public func saveAndConnectExternalLinks(html: String) -> String {
        let pattern = "href=[\"'](http[s]?://[^\"']+)[\"']"
        var updatedHTML = html
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let link = String(html[range])
                    updatedHTML = updatedHTML.replacingOccurrences(of: link, with: "local://\(link)")
                }
            }
        }
        return updatedHTML
    }
}
