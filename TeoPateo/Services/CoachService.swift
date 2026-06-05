import Foundation

enum CoachRole: String, Codable, Equatable {
    case system
    case user
    case assistant
}

struct CoachChatMessage: Equatable {
    let role: CoachRole
    let content: String
}

struct CoachRequest: Equatable {
    let contextSummary: String
    let messages: [CoachChatMessage]
}

enum CoachResponseState: Equatable {
    case ready
    case sending
    case failed(String)

    var isSending: Bool {
        if case .sending = self {
            return true
        }
        return false
    }

    var message: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

protocol CoachResponding {
    func reply(to request: CoachRequest) -> AsyncThrowingStream<String, Error>
}

enum CoachClientError: LocalizedError, Equatable {
    case missingProxyConfiguration
    #if DEBUG
    case missingAPIKey
    #endif
    case invalidHTTPResponse
    case requestFailed(statusCode: Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingProxyConfiguration:
            return "The coach is unavailable right now. Your message was saved."
        #if DEBUG
        case .missingAPIKey:
            return "The coach is unavailable right now. Your message was saved."
        #endif
        case .invalidHTTPResponse:
            return "The coach is unavailable right now. Your message was saved."
        case .requestFailed(let statusCode):
            if statusCode == 429 {
                return "The coach is getting too many requests. Try again in a minute."
            }
            return "The coach is unavailable right now. Your message was saved."
        case .emptyResponse:
            return "The coach is unavailable right now. Your message was saved."
        }
    }
}

#if DEBUG
struct OpenRouterConfiguration: Equatable {
    let apiKey: String
    let model: String
    let baseURL: URL
    let appTitle: String
    let referer: String?

    init(
        apiKey: String,
        model: String = "openai/gpt-5-mini",
        baseURL: URL = URL(string: "https://openrouter.ai/api/v1")!,
        appTitle: String = "TeoPateo",
        referer: String? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.appTitle = appTitle
        self.referer = referer
    }

    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> OpenRouterConfiguration? {
        guard let apiKey = configuredValue(
            named: "OPENROUTER_API_KEY",
            environment: environment,
            bundle: bundle
        ) else {
            return nil
        }

        let model = configuredValue(
            named: "OPENROUTER_MODEL",
            environment: environment,
            bundle: bundle
        ) ?? "openai/gpt-5-mini"
        let appTitle = configuredValue(
            named: "OPENROUTER_APP_TITLE",
            environment: environment,
            bundle: bundle
        ) ?? "TeoPateo"
        let referer = configuredValue(
            named: "OPENROUTER_REFERER",
            environment: environment,
            bundle: bundle
        )
        let baseURLString = configuredValue(
            named: "OPENROUTER_BASE_URL",
            environment: environment,
            bundle: bundle
        ) ?? "https://openrouter.ai/api/v1"
        let baseURL = URL(string: baseURLString) ?? URL(string: "https://openrouter.ai/api/v1")!

        return OpenRouterConfiguration(
            apiKey: apiKey,
            model: model,
            baseURL: baseURL,
            appTitle: appTitle,
            referer: referer
        )
    }

    private static func configuredValue(
        named name: String,
        environment: [String: String],
        bundle: Bundle
    ) -> String? {
        let value = environment[name]
            ?? bundle.object(forInfoDictionaryKey: name) as? String
            ?? UserDefaults.standard.string(forKey: name)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        return trimmed
    }
}
#endif

struct CoachProxyConfiguration: Equatable {
    let endpointURL: URL
    let accessToken: String?

    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> CoachProxyConfiguration? {
        guard let urlString = configuredValue(
            named: "TEOPATEO_COACH_PROXY_URL",
            environment: environment,
            bundle: bundle
        ), let endpointURL = URL(string: urlString) else {
            return nil
        }

        return CoachProxyConfiguration(
            endpointURL: endpointURL,
            accessToken: configuredValue(
                named: "TEOPATEO_COACH_PROXY_TOKEN",
                environment: environment,
                bundle: bundle
            )
        )
    }

    private static func configuredValue(
        named name: String,
        environment: [String: String],
        bundle: Bundle
    ) -> String? {
        let value = environment[name]
            ?? bundle.object(forInfoDictionaryKey: name) as? String
            ?? UserDefaults.standard.string(forKey: name)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        return trimmed
    }
}

struct LiveCoachClient: CoachResponding {
    private let proxyConfiguration: CoachProxyConfiguration?

    #if DEBUG
    private let openRouterConfiguration: OpenRouterConfiguration?

    init(
        proxyConfiguration: CoachProxyConfiguration? = CoachProxyConfiguration.live(),
        openRouterConfiguration: OpenRouterConfiguration? = OpenRouterConfiguration.live()
    ) {
        self.proxyConfiguration = proxyConfiguration
        self.openRouterConfiguration = openRouterConfiguration
    }
    #else
    init(proxyConfiguration: CoachProxyConfiguration? = CoachProxyConfiguration.live()) {
        self.proxyConfiguration = proxyConfiguration
    }
    #endif

    func reply(to request: CoachRequest) -> AsyncThrowingStream<String, Error> {
        if let proxyConfiguration {
            return CoachProxyClient(configuration: proxyConfiguration).reply(to: request)
        }

        #if DEBUG
        return OpenRouterCoachClient(configuration: openRouterConfiguration).reply(to: request)
        #else
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: CoachClientError.missingProxyConfiguration)
        }
        #endif
    }
}

struct CoachProxyClient: CoachResponding {
    private let configuration: CoachProxyConfiguration
    private let bytesTask: (URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: CoachProxyConfiguration,
        bytesTask: @escaping (URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) = { request in
            try await URLSession.shared.bytes(for: request)
        }
    ) {
        self.configuration = configuration
        self.bytesTask = bytesTask
    }

    func reply(to request: CoachRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await streamReply(to: request, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func streamReply(
        to request: CoachRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let urlRequest = try makeURLRequest(for: request)
        let (bytes, response) = try await bytesTask(urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachClientError.invalidHTTPResponse
        }
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard 200..<300 ~= httpResponse.statusCode else {
            _ = try await Self.collectData(from: bytes)
            throw CoachClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        guard contentType.contains("text/event-stream") else {
            try await emitBufferedProxyResponse(from: bytes, continuation: continuation)
            return
        }

        try await emitStreamChunks(from: bytes, continuation: continuation)
    }

    private func emitBufferedProxyResponse(
        from bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let data = try await Self.collectData(from: bytes)
        let decoded = try decoder.decode(CoachProxyResponse.self, from: data)
        let reply = decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else {
            throw CoachClientError.emptyResponse
        }
        continuation.yield(reply)
        continuation.finish()
    }

    private func emitStreamChunks(
        from bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        var receivedContent = false
        for try await line in bytes.lines {
            switch CoachStreamParser.event(from: line) {
            case .delta(let text):
                receivedContent = true
                continuation.yield(text)
            case .done:
                guard receivedContent else {
                    throw CoachClientError.emptyResponse
                }
                continuation.finish()
                return
            case .ignored:
                break
            }
        }

        guard receivedContent else {
            throw CoachClientError.emptyResponse
        }
        continuation.finish()
    }

    private static func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var collectedBytes: [UInt8] = []
        collectedBytes.reserveCapacity(16 * 1024)
        for try await byte in bytes {
            collectedBytes.append(byte)
        }
        return Data(collectedBytes)
    }

    func makeURLRequest(for request: CoachRequest) throws -> URLRequest {
        var urlRequest = URLRequest(url: configuration.endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("TeoPateo-iOS", forHTTPHeaderField: "X-TeoPateo-Client")
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            urlRequest.setValue(bundleVersion, forHTTPHeaderField: "X-TeoPateo-App-Version")
        }
        if let accessToken = configuration.accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpBody = try encoder.encode(CoachProxyRequest(
            contextSummary: request.contextSummary,
            stream: true,
            messages: request.messages.map {
                CoachProxyMessage(role: $0.role, content: $0.content)
            }
        ))
        return urlRequest
    }
}

#if DEBUG
struct OpenRouterCoachClient: CoachResponding {
    private let configuration: OpenRouterConfiguration?
    private let bytesTask: (URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        configuration: OpenRouterConfiguration? = OpenRouterConfiguration.live(),
        bytesTask: @escaping (URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) = { request in
            try await URLSession.shared.bytes(for: request)
        }
    ) {
        self.configuration = configuration
        self.bytesTask = bytesTask
    }

    func reply(to request: CoachRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await streamReply(to: request, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func streamReply(
        to request: CoachRequest,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let configuration else {
            throw CoachClientError.missingAPIKey
        }

        var urlRequest = URLRequest(
            url: configuration.baseURL.appendingPathComponent("chat/completions")
        )
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(configuration.appTitle, forHTTPHeaderField: "X-OpenRouter-Title")
        if let referer = configuration.referer {
            urlRequest.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        }

        let body = OpenRouterChatRequest(
            model: configuration.model,
            messages: messages(for: request),
            maxTokens: 280,
            temperature: 0.45,
            stream: true
        )
        urlRequest.httpBody = try encoder.encode(body)

        let (bytes, response) = try await bytesTask(urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachClientError.invalidHTTPResponse
        }
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard 200..<300 ~= httpResponse.statusCode else {
            _ = try await Self.collectData(from: bytes)
            throw CoachClientError.requestFailed(
                statusCode: httpResponse.statusCode
            )
        }

        guard contentType.contains("text/event-stream") else {
            try await emitBufferedOpenRouterResponse(from: bytes, continuation: continuation)
            return
        }

        try await emitStreamChunks(from: bytes, continuation: continuation)
    }

    private func emitBufferedOpenRouterResponse(
        from bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let data = try await Self.collectData(from: bytes)
        let decoded = try decoder.decode(OpenRouterChatResponse.self, from: data)
        let reply = decoded.choices
            .compactMap { $0.message.content }
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let reply, !reply.isEmpty else {
            throw CoachClientError.emptyResponse
        }
        continuation.yield(reply)
        continuation.finish()
    }

    private func emitStreamChunks(
        from bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        var receivedContent = false
        for try await line in bytes.lines {
            switch CoachStreamParser.event(from: line) {
            case .delta(let text):
                receivedContent = true
                continuation.yield(text)
            case .done:
                guard receivedContent else {
                    throw CoachClientError.emptyResponse
                }
                continuation.finish()
                return
            case .ignored:
                break
            }
        }

        guard receivedContent else {
            throw CoachClientError.emptyResponse
        }
        continuation.finish()
    }

    private func messages(for request: CoachRequest) -> [OpenRouterMessage] {
        [OpenRouterMessage(role: .system, content: Self.systemPrompt(contextSummary: request.contextSummary))]
            + request.messages.map {
            OpenRouterMessage(role: $0.role, content: $0.content)
        }
    }

    private func errorMessage(from data: Data) -> String {
        if
            let response = try? decoder.decode(OpenRouterErrorResponse.self, from: data),
            let message = response.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
            !message.isEmpty
        {
            return message
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        return "No error details were returned."
    }

    private static func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var collectedBytes: [UInt8] = []
        collectedBytes.reserveCapacity(16 * 1024)
        for try await byte in bytes {
            collectedBytes.append(byte)
        }
        return Data(collectedBytes)
    }

    private static func systemPrompt(contextSummary: String) -> String {
        """
        \(baseSystemPrompt)

        Current TeoPateo user context:
        \(contextSummary)
        """
    }

    private static let baseSystemPrompt = """
    You are TeoPateo's quit-smoking coach. Help the user get through high-risk smoking moments, refine their quit plan, reflect on check-ins, recover from slips, and understand patterns.

    Keep the tone calm, specific, and non-shaming. Treat slips as data, not failure. Prioritize the next 10 minutes: name the trigger, choose one replacement action, and lower intensity.

    Keep replies concise and practical. Do not diagnose, guarantee outcomes, or make strong medical claims. For medication, withdrawal symptoms, mental health concerns, or urgent safety concerns, direct the user to a doctor, pharmacist, quitline counselor, local emergency service, or trusted support person as appropriate.
    """
}
#endif

private struct CoachProxyRequest: Encodable {
    let contextSummary: String
    let stream: Bool
    let messages: [CoachProxyMessage]
}

private struct CoachProxyMessage: Codable {
    let role: CoachRole
    let content: String
}

private struct CoachProxyResponse: Decodable {
    let reply: String
}

#if DEBUG
private struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [OpenRouterMessage]
    let maxTokens: Int
    let temperature: Double
    let stream: Bool

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
    }
}

private struct OpenRouterMessage: Encodable {
    let role: CoachRole
    let content: String
}

private struct OpenRouterChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}
#endif

private enum CoachStreamEvent {
    case delta(String)
    case done
    case ignored
}

private enum CoachStreamParser {
    static func event(from line: String) -> CoachStreamEvent {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else {
            return .ignored
        }

        let payload = trimmed
            .dropFirst("data:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload != "[DONE]" else {
            return .done
        }
        guard let data = payload.data(using: .utf8) else {
            return .ignored
        }

        if
            let proxyDelta = try? JSONDecoder().decode(CoachProxyStreamDelta.self, from: data),
            let text = proxyDelta.delta,
            !text.isEmpty
        {
            return .delta(text)
        }

        #if DEBUG
        if
            let openRouterDelta = try? JSONDecoder().decode(OpenRouterStreamResponse.self, from: data),
            let text = openRouterDelta.choices.compactMap(\.delta?.content).first,
            !text.isEmpty
        {
            return .delta(text)
        }
        #endif

        return .ignored
    }
}

private struct CoachProxyStreamDelta: Decodable {
    let delta: String?
}

#if DEBUG
private struct OpenRouterStreamResponse: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta?
    }

    let choices: [Choice]
}

private struct OpenRouterErrorResponse: Decodable {
    struct Detail: Decodable {
        let message: String?
    }

    let error: Detail?
}
#endif
