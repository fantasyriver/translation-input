import Foundation
import TranslationCore

enum IntegrationChecks {
 static func run() async throws {
  guard let base = ProcessInfo.processInfo.environment["CHECK_ENDPOINT"],
        let key = ProcessInfo.processInfo.environment["CHECK_TOKEN"] else { fatalError("Missing fixture configuration") }
  let client = TranslationClient()
  let source = "你好 🌏\n明天见"
  for provider in LLMProvider.allCases where provider != .custom {
   var config = provider.preset; config.endpoint = base + "/" + provider.rawValue
   expectEqual(try await client.translate(text: source, language: "en", configuration: config, apiKey: key), "Hello 🌏\nSee you tomorrow")
  }
  func configuration(_ path: String) -> LLMConfiguration {
   .init(provider: .custom, endpoint: base + path, model: "fixture-model")
  }
  for status in [401, 403, 404, 429, 500, 504, 307] {
   do {
    _ = try await client.translate(text: source, language: "en", configuration: configuration("/status/\(status)"), apiKey: key)
    fatalError("Expected HTTP \(status)")
   } catch TranslationError.status(let actual) { expectEqual(actual, status) }
  }
  for path in ["/truncated", "/empty", "/malformed", "/oversized", "/oversized-chunked", "/refused"] {
   do {
    _ = try await client.translate(text: source, language: "en", configuration: configuration(path), apiKey: key)
    fatalError("Expected response rejection: \(path)")
   } catch is TranslationError {}
  }
  expectEqual(try await client.translate(text: source, language: "en", configuration: configuration("/no-key"), apiKey: ""), "Hello 🌏\nSee you tomorrow")
  for path in ["/slow-headers", "/slow-body"] {
   let start = Date()
   let pending = Task { try await client.translate(text: source, language: "en", configuration: configuration(path), apiKey: key) }
   try await Task.sleep(nanoseconds: 200_000_000)
   pending.cancel()
   do { _ = try await pending.value; fatalError("Canceled request returned a translation") }
   catch is CancellationError {} catch let error as URLError { expectEqual(error.code, .cancelled) }
   expectTrue(Date().timeIntervalSince(start) < 2)
  }
  print("PASS: real URLSession → six provider HTTP fixtures; auth/status/redirect/size/refusal/cancellation and keyless localhost")
 }
}
