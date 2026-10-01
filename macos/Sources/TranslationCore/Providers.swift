import Foundation

public enum LLMAPI: String, Codable, CaseIterable {
 case openAI, anthropic
 public var title: String { self == .openAI ? "OpenAI 兼容 · Chat Completions" : "Claude · Messages" }
}
public enum LLMProvider: String, Codable, CaseIterable {
 case openai, claude, deepseek, glm, minimax, qwen, custom
 public var title: String {
  switch self {
  case .openai: return "OpenAI / ChatGPT"
  case .claude: return "Anthropic / Claude"
  case .deepseek: return "DeepSeek"
  case .glm: return "智谱 GLM（中国区）"
  case .minimax: return "MiniMax（中国区）"
  case .qwen: return "通义千问（北京区）"
  case .custom: return "自定义服务"
  }
 }
 public var preset: LLMConfiguration {
  switch self {
  case .openai: return .init(provider: self, endpoint: "https://api.openai.com/v1/chat/completions", model: "gpt-5-nano")
  case .claude: return .init(provider: self, endpoint: "https://api.anthropic.com/v1/messages", model: "claude-haiku-4-5-20251001", api: .anthropic)
  case .deepseek: return .init(provider: self, endpoint: "https://api.deepseek.com/chat/completions", model: "deepseek-flash")
  case .glm: return .init(provider: self, endpoint: "https://open.bigmodel.cn/api/paas/v4/chat/completions", model: "glm-4.7-flash")
  case .minimax: return .init(provider: self, endpoint: "https://api.minimax.cn/v1/chat/completions", model: "MiniMax-M3")
  case .qwen: return .init(provider: self, endpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", model: "qwen-turbo")
  case .custom: return .init(provider: self, endpoint: "", model: "")
  }
 }
 public var note: String {
  switch self {
  case .openai: return "低价 Nano 模型。填写 OpenAI 平台的 API Key。"
  case .claude: return "Haiku 轻量模型，使用 Claude Messages 接口。"
  case .deepseek: return "Flash 模型；预设关闭深度思考，优先翻译速度。"
  case .glm: return "中国区 Flash 模型；预设关闭思考。额度以智谱平台为准。"
  case .minimax: return "中国区 M3 标准服务；预设关闭思考。国际区请修改 API 地址。"
  case .qwen: return "北京区 Turbo 低价模型；预设关闭思考。Key 必须与地域一致。"
  case .custom: return "填写完整接口地址并选择协议。本机 HTTP 服务允许不填 Key。"
  }
 }
}
public struct LLMConfiguration: Codable, Equatable {
 public var provider: LLMProvider
 public var endpoint: String
 public var model: String
 public var api: LLMAPI
 public init(provider: LLMProvider, endpoint: String, model: String, api: LLMAPI = .openAI) {
  self.provider = provider; self.endpoint = endpoint; self.model = model; self.api = api
 }
 public var credentialAccount: String {
  // Length-prefixed scope prevents separator collisions and never includes the model or secret.
  [provider.rawValue, api.rawValue, endpoint].map { "\($0.utf8.count):\($0)" }.joined()
 }
 public var allowsEmptyKey: Bool {
  guard provider == .custom, let url = ServiceEndpoint.validate(endpoint) else { return false }
  return ["localhost", "127.0.0.1", "[::1]", "::1"].contains(url.host ?? "")
 }
 public func validated(apiKey: String) throws -> URL {
  guard let url = ServiceEndpoint.validate(endpoint), !url.path.isEmpty, url.path != "/",
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, model.count <= 256,
        !model.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw TranslationError.invalidConfiguration }
  guard (allowsEmptyKey || !apiKey.isEmpty), apiKey.utf8.count <= 16384,
        !apiKey.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) else { throw TranslationError.invalidKey }
  return url
 }
}
public final class LLMPreferences {
 private let defaults: UserDefaults
 public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
 public var current: LLMConfiguration {
  let provider = defaults.string(forKey: "llm.provider").flatMap(LLMProvider.init(rawValue:)) ?? .openai
  return configuration(for: provider)
 }
 public func configuration(for provider: LLMProvider) -> LLMConfiguration {
  guard let data = defaults.data(forKey: "llm.profile." + provider.rawValue),
        let value = try? JSONDecoder().decode(LLMConfiguration.self, from: data), value.provider == provider else { return provider.preset }
  return value
 }
 public func save(_ configuration: LLMConfiguration) {
  guard let data = try? JSONEncoder().encode(configuration) else { return }
  defaults.set(data, forKey: "llm.profile." + configuration.provider.rawValue)
  defaults.set(configuration.provider.rawValue, forKey: "llm.provider")
 }
}
public final class CredentialDraft {
 public private(set) var configuration: LLMConfiguration
 public var apiKey: String
 private let load: (LLMConfiguration) -> String
 public init(configuration: LLMConfiguration, load: @escaping (LLMConfiguration) -> String) {
  self.configuration = configuration; self.load = load; apiKey = load(configuration)
 }
 public func update(configuration: LLMConfiguration) {
  if self.configuration.credentialAccount != configuration.credentialAccount { apiKey = load(configuration) }
  self.configuration = configuration
 }
}
