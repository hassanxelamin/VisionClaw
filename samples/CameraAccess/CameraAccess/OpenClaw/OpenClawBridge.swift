import Foundation

enum OpenClawConnectionState: Equatable {
  case notConfigured
  case checking
  case connected
  case unreachable(String)
}

@MainActor
class OpenClawBridge: ObservableObject {
  @Published var lastToolCallStatus: ToolCallStatus = .idle
  @Published var connectionState: OpenClawConnectionState = .notConfigured

  private let session: URLSession
  private let pingSession: URLSession
  private var sessionKey: String
  private var conversationHistory: [[String: String]] = []
  private let maxHistoryTurns = 10

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120
    self.session = URLSession(configuration: config)

    let pingConfig = URLSessionConfiguration.default
    pingConfig.timeoutIntervalForRequest = 5
    self.pingSession = URLSession(configuration: pingConfig)

    self.sessionKey = OpenClawBridge.newSessionKey()
  }

  func checkConnection() async {
    guard GeminiConfig.isOpenClawConfigured else {
      connectionState = .notConfigured
      return
    }
    connectionState = .checking
    guard let healthURL = URL(string: "\(GeminiConfig.openClawHost):\(GeminiConfig.openClawPort)/health") else {
      connectionState = .unreachable("Invalid URL")
      return
    }
    var request = URLRequest(url: healthURL)
    request.httpMethod = "GET"
    do {
      let (_, response) = try await pingSession.data(for: request)
      if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
        connectionState = .connected
        NSLog("[OpenClaw] Gateway reachable (HTTP %d)", http.statusCode)
      } else {
        connectionState = .unreachable("Unexpected response")
      }
    } catch {
      let normalized = normalizedConnectivityError(error)
      connectionState = .unreachable(normalized)
      NSLog("[OpenClaw] Gateway unreachable: %@", normalized)
    }
  }

  func resetSession() {
    sessionKey = OpenClawBridge.newSessionKey()
    conversationHistory = []
    NSLog("[OpenClaw] New session: %@", sessionKey)
  }

  private static func newSessionKey() -> String {
    let ts = ISO8601DateFormatter().string(from: Date())
    return "agent:main:glass:\(ts)"
  }

  // MARK: - Agent Chat (session continuity via x-openclaw-session-key header)

  func delegateTask(
    task: String,
    toolName: String = "execute"
  ) async -> ToolResult {
    lastToolCallStatus = .executing(toolName)

    guard GeminiConfig.isOpenClawConfigured else {
      connectionState = .notConfigured
      lastToolCallStatus = .failed(toolName, "OpenClaw not configured")
      return .failure("OpenClaw is not configured.")
    }

    guard let url = URL(string: "\(GeminiConfig.openClawHost):\(GeminiConfig.openClawPort)/v1/chat/completions") else {
      connectionState = .unreachable("Invalid URL")
      lastToolCallStatus = .failed(toolName, "Invalid URL")
      return .failure("Invalid gateway URL")
    }

    // Append the new user message to conversation history
    conversationHistory.append(["role": "user", "content": task])

    // Trim history to keep only the most recent turns (user+assistant pairs)
    if conversationHistory.count > maxHistoryTurns * 2 {
      conversationHistory = Array(conversationHistory.suffix(maxHistoryTurns * 2))
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 45
    request.setValue("Bearer \(GeminiConfig.openClawGatewayToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(sessionKey, forHTTPHeaderField: "x-openclaw-session-key")

    let body: [String: Any] = [
      "model": "openclaw",
      "messages": conversationHistory,
      "stream": false
    ]

    NSLog("[OpenClaw] Sending %d messages in conversation", conversationHistory.count)

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, response) = try await session.data(for: request)
      let httpResponse = response as? HTTPURLResponse

      guard let statusCode = httpResponse?.statusCode, (200...299).contains(statusCode) else {
        let code = httpResponse?.statusCode ?? 0
        let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
        NSLog("[OpenClaw] Chat failed: HTTP %d - %@", code, String(bodyStr.prefix(200)))
        connectionState = .unreachable("HTTP \(code)")
        lastToolCallStatus = .failed(toolName, "HTTP \(code)")
        return .failure("Agent returned HTTP \(code)")
      }

      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let choices = json["choices"] as? [[String: Any]],
         let first = choices.first,
         let message = first["message"] as? [String: Any],
         let content = message["content"] as? String {
        // Append assistant response to history for continuity
        conversationHistory.append(["role": "assistant", "content": content])
        connectionState = .connected
        NSLog("[OpenClaw] Agent result: %@", String(content.prefix(200)))
        lastToolCallStatus = .completed(toolName)
        return .success(content)
      }

      let raw = String(data: data, encoding: .utf8) ?? "OK"
      conversationHistory.append(["role": "assistant", "content": raw])
      connectionState = .connected
      NSLog("[OpenClaw] Agent raw: %@", String(raw.prefix(200)))
      lastToolCallStatus = .completed(toolName)
      return .success(raw)
    } catch {
      let normalized = normalizedConnectivityError(error)
      connectionState = .unreachable(normalized)
      NSLog("[OpenClaw] Agent error: %@", normalized)
      lastToolCallStatus = .failed(toolName, normalized)
      return .failure("Agent error: \(normalized)")
    }
  }

  // MARK: - Connectivity Error Normalization

  private func normalizedConnectivityError(_ error: Error) -> String {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .timedOut:
        return "Request timed out"
      case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
        return "Host unreachable"
      case .networkConnectionLost, .notConnectedToInternet:
        return "Network unavailable"
      default:
        return urlError.localizedDescription
      }
    }
    return error.localizedDescription
  }
}
