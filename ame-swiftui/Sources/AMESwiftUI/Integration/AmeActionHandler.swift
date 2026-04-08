import Foundation

/// Protocol for host app action dispatch.
///
/// The host app implements this protocol to route actions to its own systems:
/// - `.callTool` -> host app's tool execution pipeline
/// - `.openUri` -> URL opening (e.g., UIApplication.shared.open)
/// - `.navigate` -> host app's navigation system
/// - `.copyText` -> clipboard (e.g., UIPasteboard.general.string)
/// - `.submit` -> NEVER received (renderer converts to `.callTool` before dispatch)
///
/// The renderer invokes the action handler callback — the protocol exists
/// as a type-safe contract for documentation and dependency injection.
public protocol AmeActionHandler {
    func handleAction(_ action: AmeAction)
}
