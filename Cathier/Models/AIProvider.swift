import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case claude    = "claude"
    case openai    = "openai"
    case deepseek  = "deepseek"
    case qwen      = "qwen"
    case zhipu     = "zhipu"
    case openrouter = "openrouter"
    case acedata   = "acedata"
    /// Managed tier — developer's key is used at build time
    case managed   = "managed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:    return "Claude"
        case .openai:    return "OpenAI"
        case .deepseek:  return "DeepSeek"
        case .qwen:      return "通义千问"
        case .zhipu:     return "智谱 AI"
        case .openrouter: return "OpenRouter"
        case .acedata:   return "AceData"
        case .managed:   return "我没有 API Key"
        }
    }

    var endpoint: URL {
        switch self {
        case .claude:    return URL(string: "https://api.anthropic.com/v1/messages")!
        case .openai:    return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .deepseek:  return URL(string: "https://api.deepseek.com/v1/chat/completions")!
        case .qwen:
            return URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
        case .zhipu:     return URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
        case .openrouter:
            return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        case .acedata, .managed:
            return URL(string: "https://api.acedata.cloud/openai/chat/completions")!
        }
    }

    /// Lightweight model for per-session feedback (fast, cheap)
    var feedbackModel: String {
        switch self {
        case .claude:     return "claude-haiku-4-5-20251001"
        case .openai:     return "gpt-4o-mini"
        case .deepseek:   return "deepseek-chat"
        case .qwen:       return "qwen-turbo"
        case .zhipu:      return "glm-4-flash"
        case .openrouter: return "moonshotai/kimi-k2.6"
        case .acedata, .managed: return "gpt-5.5-pro"
        }
    }

    /// Smarter model for deep pattern analysis
    var insightsModel: String {
        switch self {
        case .claude:     return "claude-sonnet-4-6"
        case .openai:     return "gpt-4o"
        case .deepseek:   return "deepseek-chat"
        case .qwen:       return "qwen-plus"
        case .zhipu:      return "glm-4"
        case .openrouter: return "moonshotai/kimi-k2.6"
        case .acedata, .managed: return "gpt-5.5-pro"
        }
    }

    /// UserDefaults key where this provider's API key is stored (unused for .managed)
    var apiKeyStorageKey: String { "\(rawValue)ApiKey" }

    /// Placeholder text for the key input field
    var keyPlaceholder: String {
        switch self {
        case .claude:    return "sk-ant-…"
        case .openai:    return "sk-…"
        case .deepseek:  return "sk-…"
        case .qwen:      return "sk-…"
        case .zhipu:     return "…"
        case .openrouter: return "sk-or-…"
        case .acedata:   return "…"
        case .managed:   return ""
        }
    }

    /// Link to the provider's API console (nil for managed)
    var consoleURL: URL? {
        switch self {
        case .claude:    return URL(string: "https://console.anthropic.com")
        case .openai:    return URL(string: "https://platform.openai.com/api-keys")
        case .deepseek:  return URL(string: "https://platform.deepseek.com")
        case .qwen:      return URL(string: "https://dashscope.console.aliyun.com")
        case .zhipu:     return URL(string: "https://open.bigmodel.cn")
        case .openrouter: return URL(string: "https://openrouter.ai/keys")
        case .acedata:   return URL(string: "https://acedata.cloud")
        case .managed:   return nil
        }
    }

    /// Whether this provider uses the Anthropic wire format (vs. OpenAI-compatible)
    var isAnthropicFormat: Bool { self == .claude }

    /// Whether this is the developer-managed tier
    var isManaged: Bool { self == .managed }
}
