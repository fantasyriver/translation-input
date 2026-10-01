import Foundation

public struct TranslationSession {
 private var active: UUID?
 public init() {}
 public mutating func begin() -> UUID { let id = UUID(); active = id; return id }
 public mutating func cancel() { active = nil }
 public func isCurrent(_ id: UUID) -> Bool { active == id }
 public mutating func consume(_ id: UUID) -> Bool {
  guard active == id else { return false }; active = nil; return true
 }
}
public enum ServiceEndpoint {
 public static func validate(_ value: String) -> URL? {
  guard let url = URL(string: value), let host = url.host, !host.isEmpty,
        url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
        url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)) else { return nil }
  return url
 }
}
public struct TargetLanguage {
 public let code: String
 public let title: String
 public static let all: [TargetLanguage] = [
  .init(code: "en", title: "English"), .init(code: "zh-Hans", title: "简体中文"), .init(code: "zh-Hant", title: "繁體中文"),
  .init(code: "ja", title: "日本語"), .init(code: "ko", title: "한국어"), .init(code: "fr", title: "Français"),
  .init(code: "de", title: "Deutsch"), .init(code: "es", title: "Español"), .init(code: "pt", title: "Português"),
  .init(code: "it", title: "Italiano"), .init(code: "ru", title: "Русский"), .init(code: "ar", title: "العربية")]
}
