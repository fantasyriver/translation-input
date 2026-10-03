import Foundation

public struct DeliveryOutcome: Equatable {
 public enum Insertion: Equatable { case skipped, sent, failed }
 public let copied: Bool
 public let insertion: Insertion
}
@MainActor public enum TranslationDelivery {
 public static func deliver(_ text: String, canAutoFill: Bool, isValid: () -> Bool,
                            show: (String) -> Void, copy: (String) -> Bool,
                            insert: (String) async throws -> Void) async throws -> DeliveryOutcome {
  guard isValid(), !Task.isCancelled else { throw CancellationError() }
  show(text)
  let copied = copy(text)
  guard canAutoFill else { return DeliveryOutcome(copied: copied, insertion: .skipped) }
  do {
   try await insert(text)
   guard isValid(), !Task.isCancelled else { throw CancellationError() }
   return DeliveryOutcome(copied: copied, insertion: .sent)
  } catch {
   guard isValid(), !Task.isCancelled, !(error is CancellationError) else { throw CancellationError() }
   return DeliveryOutcome(copied: copied, insertion: .failed)
  }
 }
}
