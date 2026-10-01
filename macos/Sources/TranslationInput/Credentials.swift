import Foundation
import Security
import TranslationCore

enum Credentials {
 private static func query(configuration: LLMConfiguration) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "local.translationinput.provider-api-key", kSecAttrAccount as String: configuration.credentialAccount] }
 static func read(configuration: LLMConfiguration) -> String? {
  var q = query(configuration: configuration); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
  var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
  return String(data: data, encoding: .utf8)
 }
 static func save(_ value: String, configuration: LLMConfiguration) throws {
  let query = query(configuration: configuration)
  let data = Data(value.utf8)
  var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
  if status == errSecItemNotFound { var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly; status = SecItemAdd(q as CFDictionary, nil) }
  guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "无法保存 API Key到钥匙串（\(status)）。"]) }
 }
}
