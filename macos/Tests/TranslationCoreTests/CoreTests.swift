import Foundation
import Darwin
import TranslationCore
final class CoreTests {
 func testShortcutAppliesWithoutServiceConfiguration() {
  let commandSpace = HotKey(keyCode: 49, modifiers: 256, label: "⌘ Space")
  var registered: HotKey?; var persisted: HotKey?
  let binding = ShortcutBinding(current: .standard, register: { registered = $0; return 0 }, persist: { persisted = $0 })
  expectEqual(binding.apply(commandSpace), 0)
  expectEqual(registered, commandSpace); expectEqual(persisted, commandSpace); expectEqual(binding.current, commandSpace)
 }
 func testFailedShortcutKeepsEffectiveValue() {
  var writes = 0
  let binding = ShortcutBinding(current: .standard, register: { _ in -9878 }, persist: { _ in writes += 1 })
  expectEqual(binding.apply(HotKey(keyCode: 49, modifiers: 256, label: "⌘ Space")), -9878)
  expectEqual(binding.current, .standard); expectEqual(writes, 0)
 }
 func testSystemShortcutConflictUsesEnabledActualCombination() {
  let command = HotKey(keyCode: 49, modifiers: 256, label: "⌘ Space")
  let option = HotKey.standard
  let rows = [SystemShortcut(keyCode: 49, modifiers: 2048, enabled: true), SystemShortcut(keyCode: 49, modifiers: 256, enabled: false)]
  expectFalse(command.conflicts(with: rows)); expectTrue(option.conflicts(with: rows))
 }
 func testCanceledResponseCannotInsert() {
  var session = TranslationSession(); let ticket = session.begin()
  session.cancel()
  expectFalse(session.consume(ticket))
 }
 func testInsertionOnlyOnce() {
  var session = TranslationSession(); let ticket = session.begin()
  expectTrue(session.consume(ticket)); expectFalse(session.consume(ticket))
 }
 func testNewSessionInvalidatesOldRequest() {
  var session = TranslationSession(); let old = session.begin(); let new = session.begin()
  expectFalse(session.consume(old)); expectTrue(session.consume(new))
 }
 func testEndpointPolicy() {
  expectNotNil(ServiceEndpoint.validate("http://127.0.0.1:8787"))
  expectNotNil(ServiceEndpoint.validate("https://example.com"))
  expectNil(ServiceEndpoint.validate("http://example.com"))
  expectNil(ServiceEndpoint.validate("https://user:pass@example.com"))
  expectNil(ServiceEndpoint.validate("https://example.com?token=secret"))
 }
 func testProviderRequests() throws {
  for provider in LLMProvider.allCases {
   var config = provider.preset
   if provider == .custom { config.endpoint = "http://localhost:11434/v1/chat/completions"; config.model = "local-model" }
   let request = try LLMWire.request(text: "你好 🌏\n明天见", language: "en", configuration: config, apiKey: "test-key")
   expectEqual(request.url?.absoluteString, config.endpoint)
   expectEqual(request.httpMethod, "POST")
   let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
   expectEqual(body["model"] as? String, config.model)
   let messages = body["messages"] as! [[String: String]]
   expectEqual(messages.last?["content"], "你好 🌏\n明天见")
   if provider == .claude {
    expectEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
    expectNil(request.value(forHTTPHeaderField: "Authorization"))
    expectEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
    expectNotNil(body["system"]); expectEqual(messages.count, 1)
   } else { expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key"); expectEqual(messages.first?["role"], "system") }
   if provider == .deepseek || provider == .glm || provider == .minimax { expectEqual((body["thinking"] as? [String: String])?["type"], "disabled") }
   if provider == .qwen { expectEqual(body["enable_thinking"] as? Bool, false) }
  }
  expectThrowsError(try LLMWire.request(text: "hello", language: "xx", configuration: LLMProvider.openai.preset, apiKey: "key"))
  expectThrowsError(try LLMWire.request(text: " ", language: "en", configuration: LLMProvider.openai.preset, apiKey: "key"))
  expectThrowsError(try LLMWire.request(text: "hello", language: "en", configuration: LLMProvider.openai.preset, apiKey: "bad\r\nkey"))
 }
 func testProviderResponses() throws {
  func chat(_ content: String, _ reason: String = "stop", refusal: String? = nil) throws -> Data {
   var message: [String: Any] = ["content": content, "role": "assistant"]
   if let refusal { message["refusal"] = refusal }
   return try JSONSerialization.data(withJSONObject: ["choices": [["message": message, "finish_reason": reason]]])
  }
  let config = LLMProvider.openai.preset
  expectEqual(try LLMWire.translation(from: chat("Hello 🌏\nSee you"), configuration: config), "Hello 🌏\nSee you")
  expectThrowsError(try LLMWire.translation(from: chat("partial", "length"), configuration: config))
  expectThrowsError(try LLMWire.translation(from: chat("blocked", "content_filter"), configuration: config))
  expectThrowsError(try LLMWire.translation(from: chat("refused", refusal: "no"), configuration: config))
  expectThrowsError(try LLMWire.translation(from: chat(" "), configuration: config))
  expectThrowsError(try LLMWire.translation(from: Data("{}".utf8), configuration: config))
  expectThrowsError(try LLMWire.translation(from: chat(String(repeating: "a", count: 256 * 1024 + 1)), configuration: config))
  for toolCalls: Any in [NSNull(), [Any]()] {
   let response: [String: Any] = ["choices": [["message": ["role": "assistant", "content": "Hello", "tool_calls": toolCalls], "finish_reason": "stop"]]]
   expectEqual(try LLMWire.translation(from: JSONSerialization.data(withJSONObject: response), configuration: config), "Hello")
  }
  for toolCalls: Any in [["fake-call"], "invalid"] {
   let response: [String: Any] = ["choices": [["message": ["role": "assistant", "content": "Hello", "tool_calls": toolCalls], "finish_reason": "stop"]]]
   expectThrowsError(try LLMWire.translation(from: JSONSerialization.data(withJSONObject: response), configuration: config))
  }
  let anthropic: [String: Any] = ["type": "message", "role": "assistant", "stop_reason": "end_turn", "content": [["type": "thinking", "thinking": "private"], ["type": "text", "text": "Hello"], ["type": "text", "text": " world"]]]
  expectEqual(try LLMWire.translation(from: JSONSerialization.data(withJSONObject: anthropic), configuration: LLMProvider.claude.preset), "Hello world")
  var truncated = anthropic; truncated["stop_reason"] = "max_tokens"
  expectThrowsError(try LLMWire.translation(from: JSONSerialization.data(withJSONObject: truncated), configuration: LLMProvider.claude.preset))
  // MiniMax reasoning is never pasted if a gateway ignores reasoning_split.
  expectEqual(try LLMWire.translation(from: chat("<think>private</think>\nHello"), configuration: LLMProvider.minimax.preset), "Hello")
  expectThrowsError(try LLMWire.translation(from: chat("<think>unterminated"), configuration: LLMProvider.minimax.preset))
 }
 func testCredentialScopeAndProfiles() throws {
  let first = LLMProvider.openai.preset
  var changed = first; changed.endpoint = "https://another.example/v1/chat/completions"
  expectFalse(first.credentialAccount == changed.credentialAccount)
  changed = first; changed.provider = .custom
  expectFalse(first.credentialAccount == changed.credentialAccount)
  changed = first; changed.api = .anthropic
  expectFalse(first.credentialAccount == changed.credentialAccount)
  changed = first; changed.model = "different-model"
  expectEqual(first.credentialAccount, changed.credentialAccount)
  let suite = "translationinput-tests-" + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set("http://127.0.0.1:8787", forKey: "endpoint")
  defaults.set("preserve-shortcut", forKey: "shortcut")
  let store = LLMPreferences(defaults: defaults)
  expectEqual(store.current, LLMProvider.openai.preset)
  store.save(changed); store.save(LLMProvider.claude.preset)
  expectEqual(store.current, LLMProvider.claude.preset)
  expectEqual(store.configuration(for: .openai).model, "different-model")
  expectEqual(defaults.string(forKey: "shortcut"), "preserve-shortcut")
  var loaded = [String]()
  let draft = CredentialDraft(configuration: first) { loaded.append($0.credentialAccount); return $0.provider == .openai && $0.endpoint == first.endpoint ? "openai-key" : "" }
  expectEqual(draft.apiKey, "openai-key")
  draft.update(configuration: LLMProvider.claude.preset)
  expectEqual(draft.apiKey, "")
  draft.update(configuration: first); expectEqual(draft.apiKey, "openai-key")
  var other = first; other.endpoint = "https://other.example/v1/chat/completions"
  draft.update(configuration: other); expectEqual(draft.apiKey, "")
  expectEqual(loaded.count, 4)
 }
}

func expectTrue(_ value: Bool) { precondition(value) }
func expectFalse(_ value: Bool) { precondition(!value) }
func expectNil<T>(_ value: T?) { precondition(value == nil) }
func expectNotNil<T>(_ value: T?) { precondition(value != nil) }
func expectEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b, "Values differ") }
func expectThrowsError<T>(_ body: @autoclosure () throws -> T) { do { _ = try body(); fatalError("Expected rejection") } catch {} }
@main struct Checks {
 static func main() async throws {
  let tests = CoreTests()
  tests.testCanceledResponseCannotInsert(); tests.testInsertionOnlyOnce(); tests.testNewSessionInvalidatesOldRequest()
  tests.testEndpointPolicy(); try tests.testProviderRequests(); try tests.testProviderResponses(); try tests.testCredentialScopeAndProfiles()
  tests.testShortcutAppliesWithoutServiceConfiguration(); tests.testFailedShortcutKeepsEffectiveValue(); tests.testSystemShortcutConflictUsesEnabledActualCombination()
  print("PASS: 10 core behavior groups")
  if CommandLine.arguments.contains("--integration") { try await IntegrationChecks.run() }
 }
}
