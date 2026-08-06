pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai
import qs.services.deferred

/**
 * Multi-provider LLM chat orchestration.
 *
 * Conversation state and API strategies remain here. Provider health, live
 * model discovery and normalized capability metadata live in
 * AiProviderCatalog so the UI does not depend on hardcoded model IDs.
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property bool _initialized: false
    property var _lastInterfaceMessage: null

    property Component aiMessageComponent: AiMessageData {}
    property Component aiModelComponent: AiModel {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    property Component openaiResponseApiStrategy: OpenAiResponseApiStrategy {}
    property Component mistralApiStrategy: MistralApiStrategy {}
    property Component anthropicApiStrategy: AnthropicApiStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished()

    IpcHandler {
        target: "ai"

        function ensureInitialized(): void { root.ensureInitialized() }
        function diagnose(): string {
            const policy = (Config.options?.policies?.ai ?? 0)
            const model = root.models?.[root.currentModelId]
            return JSON.stringify({
                initialized: root._initialized,
                policy,
                currentModelId: root.currentModelId ?? "",
                currentModelName: model?.name ?? "",
                currentModelEndpoint: model?.endpoint ?? "",
                currentModelRequiresKey: !!model?.requires_key,
                apiKeysLoaded: !!KeyringStorage.loaded,
                currentModelHasApiKey: !!root.currentModelHasApiKey,
                currentModelReady: !!root.currentModelReady,
                modelCount: (root.modelList ?? []).length,
                runnableModelCount: (root.runnableModelList ?? []).length,
                lockedModelCount: (root.lockedModelList ?? []).length,
                modelList: root.modelList ?? [],
                currentTool: root.currentTool ?? "",
                availableTools: [...(root.availableTools ?? [])],
                safeActionCount: root._aiSafeActions("").length,
                temperature: root.temperature,
                catalog: {
                    refreshing: AiProviderCatalog.refreshing,
                    modelCount: AiProviderCatalog.availableModelCount,
                    freeModelCount: AiProviderCatalog.freeModelCount,
                    localModelCount: AiProviderCatalog.localModelCount,
                    healthyProviderCount: AiProviderCatalog.healthyProviderCount,
                    lastRefreshEpoch: AiProviderCatalog.lastRefreshEpoch,
                },
                lastInterfaceMessage: root._lastInterfaceMessage ?? "",
            })
        }

        function refreshCatalog(): void {
            root.ensureInitialized()
            AiProviderCatalog.refreshAll()
        }

        function catalog(query: string): string {
            root.ensureInitialized()
            const normalizedQuery = String(query ?? "").trim().toLowerCase()
            const matches = (AiProviderCatalog.models ?? []).filter(model => {
                if (!normalizedQuery) return true
                return `${model.providerId} ${model.remoteId} ${model.displayName}`
                    .toLowerCase().includes(normalizedQuery)
            }).slice(0, 100)
            return JSON.stringify(matches.map(model => ({
                providerId: model.providerId,
                remoteId: model.remoteId,
                displayName: model.displayName,
                local: !!model.local,
                free: !!model.free,
                inputModalities: model.inputModalities ?? [],
                capabilities: model.capabilities ?? ({}),
                contextTokens: model.contextTokens ?? 0,
                expiresAt: model.expiresAt ?? "",
                endpoint: model.endpoint ?? "",
                apiFormat: model.apiFormat ?? "openai",
                authScheme: model.authScheme ?? "strategy",
            })))
        }

        function providers(): string {
            root.ensureInitialized()
            return JSON.stringify(AiProviderCatalog.providers.map(provider => ({
                id: provider.id,
                name: provider.name,
                local: !!provider.local,
                free: !!provider.free,
                state: AiProviderCatalog.stateFor(provider.id),
            })))
        }

        function run(inputText: string): void {
            const text = (inputText ?? "").trim()
            if (text.length === 0) return

            root.ensureInitialized()

            const prefix = "/"
            if (!text.startsWith(prefix)) {
                root.sendUserMessage(text)
                return
            }

            const parts = text.split(" ")
            const command = (parts[0] ?? "").substring(1)
            const args = parts.slice(1)

            switch (command) {
                case "attach":
                    const attachPath = args.join(" ").trim()
                    if (attachPath.length === 0) {
                        root.addMessage(Translation.tr("Usage: %1attach PATH").arg(prefix), root.interfaceRole)
                        break
                    }
                    root.attachFile(attachPath)
                    break
                case "model":
                    if (args.length === 0 || !args[0] || args[0] === "get") {
                        root.addMessage(Translation.tr("Usage: %1model MODEL_ID").arg(prefix), root.interfaceRole)
                        break
                    }
                    root.setModel(args[0])
                    break
                case "tool":
                    if (args.length === 0 || args[0] === "get") {
                        root.addMessage(Translation.tr("Usage: %1tool TOOL_NAME").arg(prefix), root.interfaceRole)
                        break
                    }
                    if (root.setTool(args[0])) {
                        root.addMessage(Translation.tr("Tool set to: %1").arg(args[0]), root.interfaceRole)
                    }
                    break
                case "prompt":
                    if (args.length === 0 || args[0] === "get") {
                        root.printPrompt()
                        break
                    }
                    root.loadPrompt(args.join(" ").trim())
                    break
                case "key":
                    root.addMessage(
                        Translation.tr("The /key command is disabled over IPC"),
                        root.interfaceRole
                    )
                    break
                case "save": {
                    const joined = args.join(" ").trim()
                    if (joined.length === 0) {
                        root.addMessage(Translation.tr("Usage: %1save CHAT_NAME").arg(prefix), root.interfaceRole)
                        break
                    }
                    root.saveChat(joined)
                    break
                }
                case "load": {
                    const joined = args.join(" ").trim()
                    if (joined.length === 0) {
                        root.addMessage(Translation.tr("Usage: %1load CHAT_NAME").arg(prefix), root.interfaceRole)
                        break
                    }
                    root.loadChat(joined)
                    break
                }
                case "clear":
                    root.clearMessages()
                    break
                case "temp":
                    if (args.length === 0 || args[0] === "get") root.printTemperature()
                    else root.setTemperature(args[0])
                    break
                default:
                    root.addMessage(Translation.tr("Unknown command: ") + command, root.interfaceRole)
                    break
            }
        }

        function runGet(inputText: string): string {
            root._lastInterfaceMessage = null
            run(inputText)
            return root._lastInterfaceMessage ?? ""
        }
    }

    property string systemPrompt: {
        let prompt = Config.options?.ai?.systemPrompt ?? "";
        for (let key in root.promptSubstitutions) {
            // prompt = prompt.replaceAll(key, root.promptSubstitutions[key]);
            // QML/JS doesn't support replaceAll, so use split/join
            prompt = prompt.split(key).join(root.promptSubstitutions[key]);
        }
        return prompt;
    }
    // property var messages: []
    property var messageIDs: []
    property var messageByID: ({})
    property bool _pendingRequest: false
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded

    function hasApiKeyForModel(model): bool {
        if (!model || !model.requires_key) return true
        if (!root.apiKeysLoaded) return false
        return (root.apiKeys[model.key_id]?.length ?? 0) > 0
    }

    function publicCredentialForModel(model): string {
        // OpenCode itself uses the literal public credential for Zen's free
        // catalog when no private account key is configured.
        if ((model?.provider_id ?? "") === "opencode-zen" && model?.free === true)
            return "public"
        return ""
    }

    function credentialForModel(model): string {
        if (!model?.requires_key) return ""
        if (!root.apiKeysLoaded) return ""
        const stored = root.apiKeys[model.key_id] ?? ""
        return stored.length > 0 ? stored : root.publicCredentialForModel(model)
    }

    function modelCanRun(model): bool {
        if (!model) return false
        if ((Config.options?.policies?.ai ?? 0) === 2 && !model.local) return false
        return !model.requires_key || root.credentialForModel(model).length > 0
    }

    readonly property bool currentModelHasApiKey: root.hasApiKeyForModel(models[currentModelId])
    readonly property bool currentModelReady: root.modelCanRun(models[currentModelId])
    property var postResponseHook
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    function idForMessage(message) {
        // Generate a unique ID using timestamp and random value
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function safeModelName(modelName) {
        return (modelName ?? "")
            .toLowerCase()
            .replace(/:/g, "_")
            .replace(/ /g, "-")
            .replace(/\//g, "-")
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})` 
    }

    // Gemini: https://ai.google.dev/gemini-api/docs/function-calling
    // OpenAI: https://platform.openai.com/docs/guides/function-calling
    // Temporary override used by switch_to_search_mode; assigning currentTool
    // directly would sever the Config binding for the rest of the session
    property string _toolOverride: ""
    property string currentTool: _toolOverride.length > 0 ? _toolOverride : (Config.options?.ai?.tool ?? "search")
    property var tools: {
        "gemini": {
            "functions": [{"functionDeclarations": [
                {
                    "name": "switch_to_search_mode",
                    "description": "Search the web",
                },
                {
                    "name": "get_shell_config",
                    "description": "Get the desktop shell config file contents",
                },
                {
                    "name": "get_shell_actions",
                    "description": "Search iNiR's typed action registry before requesting a shell action.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": { "type": "string", "description": "Action search query" }
                        }
                    }
                },
                {
                    "name": "set_shell_config",
                    "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "key": {
                                "type": "string",
                                "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                            },
                            "value": {
                                "type": "string",
                                "description": "The value to set, e.g. `true`"
                            }
                        },
                        "required": ["key", "value"]
                    }
                },
                {
                    "name": "run_shell_action",
                    "description": "Run a named action from iNiR's safe action registry after user approval.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "action_id": {
                                "type": "string",
                                "description": "Stable action id from get_shell_actions"
                            },
                            "args": {
                                "type": "string",
                                "description": "Optional action arguments"
                            }
                        },
                        "required": ["action_id"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run",
                            },
                        },
                        "required": ["command"]
                    }
                },
            ]}],
            "search": [{
                "google_search": {}
            }],
            "none": []
        },
        "openai": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {
                            "type": "object",
                            "properties": {}
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_actions",
                        "description": "Search iNiR's typed action registry before requesting a shell action.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Action search query" }
                            }
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_action",
                        "description": "Run a named action from iNiR's safe action registry after user approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action_id": { "type": "string", "description": "Stable action id" },
                                "args": { "type": "string", "description": "Optional action arguments" }
                            },
                            "required": ["action_id"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        },
        "mistral": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {
                            "type": "object",
                            "properties": {}
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_actions",
                        "description": "Search iNiR's typed action registry before requesting a shell action.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Action search query" }
                            }
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_action",
                        "description": "Run a named action from iNiR's safe action registry after user approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action_id": { "type": "string", "description": "Stable action id" },
                                "args": { "type": "string", "description": "Optional action arguments" }
                            },
                            "required": ["action_id"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        },
        "anthropic": {
            "functions": [
                {
                    "name": "get_shell_config",
                    "description": "Get the desktop shell config file contents",
                    "input_schema": {
                        "type": "object",
                        "properties": {},
                    }
                },
                {
                    "name": "get_shell_actions",
                    "description": "Search iNiR's typed action registry before requesting a shell action.",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "query": { "type": "string", "description": "Action search query" }
                        }
                    }
                },
                {
                    "name": "run_shell_action",
                    "description": "Run a named action from iNiR's safe action registry after user approval.",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "action_id": { "type": "string", "description": "Stable action id" },
                            "args": { "type": "string", "description": "Optional action arguments" }
                        },
                        "required": ["action_id"]
                    }
                },
                {
                    "name": "set_shell_config",
                    "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "key": {
                                "type": "string",
                                "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                            },
                            "value": {
                                "type": "string",
                                "description": "The value to set, e.g. `true`"
                            }
                        },
                        "required": ["key", "value"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run",
                            },
                        },
                        "required": ["command"]
                    }
                },
            ],
            "search": [],
            "none": [],
        },
        "openai-response": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {
                            "type": "object",
                            "properties": {}
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_actions",
                        "description": "Search iNiR's typed action registry before requesting a shell action.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Action search query" }
                            }
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_action",
                        "description": "Run a named action from iNiR's safe action registry after user approval.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action_id": { "type": "string", "description": "Stable action id" },
                                "args": { "type": "string", "description": "Optional action arguments" }
                            },
                            "required": ["action_id"]
                        }
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        }
    }
    function _toolDeclarationName(apiFormat: string, declaration): string {
        if (apiFormat === "gemini") return declaration?.name ?? ""
        if (apiFormat === "anthropic") return declaration?.name ?? ""
        return declaration?.function?.name ?? ""
    }

    function toolsForRequest(apiFormat: string, mode: string): var {
        const map = root.tools[apiFormat]
        if (!map) return []
        if (mode === "advanced") return map.functions ?? []
        if (mode !== "functions") return map[mode] ?? []

        // Normal shell tools never expose arbitrary bash. The advanced mode is
        // explicit and every raw command still requires user approval.
        if (apiFormat === "gemini") {
            const declarations = map.functions?.[0]?.functionDeclarations ?? []
            return [{
                functionDeclarations: declarations.filter(tool => tool.name !== "run_shell_command")
            }]
        }
        return (map.functions ?? []).filter(tool =>
            root._toolDeclarationName(apiFormat, tool) !== "run_shell_command")
    }

    property list<var> availableTools: {
        const fmt = models[currentModelId]?.api_format
        const map = fmt ? root.tools[fmt] : null
        if (!map) return []
        const modes = []
        if ((map.functions?.length ?? 0) > 0) {
            modes.push("functions")
            modes.push("advanced")
        }
        if ((map.search?.length ?? 0) > 0) modes.push("search")
        modes.push("none")
        return modes
    }
    property var toolDescriptions: {
        "functions": Translation.tr("Use safe shell functions. Configuration changes require approval; arbitrary commands are hidden."),
        "advanced": Translation.tr("Also allow raw shell commands. Every command requires explicit approval."),
        "search": Translation.tr("Use the provider's native web search when available."),
        "none": Translation.tr("Disable tools")
    }

    // Model properties:
    // - name: Name of the model
    // - icon: Icon name of the model
    // - description: Description of the model
    // - endpoint: Endpoint of the model
    // - model: Model name of the model
    // - requires_key: Whether the model requires an API key
    // - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
    // - key_get_link: Link to get an API key
    // - key_get_description: Description of pricing and how to get an API key
    // - api_format: The API format of the model. Can be "openai" or "gemini". Default is "openai".
    // - extraParams: Extra parameters to be passed to the model. This is a JSON object.
    // Models loaded dynamically from config.json ai.extraModels
    property var models: (Config.options?.policies?.ai ?? 0) === 2 ? {} : ({})
    property var modelList: Object.keys(root.models)
    readonly property var runnableModelList: root.modelList.filter(id => root.modelCanRun(root.models[id]))
    readonly property var lockedModelList: root.modelList.filter(id => !root.modelCanRun(root.models[id]))
    property string currentModelId: ""

    function _resolvedCurrentModelId(): string {
        const saved = Persistent.states?.ai?.model ?? ""
        if (saved && root.models[saved] && root.modelCanRun(root.models[saved])) return saved
        if (root.currentModelId && root.models[root.currentModelId]
                && root.modelCanRun(root.models[root.currentModelId])) return root.currentModelId
        const recommended = root.recommendedModelIds("auto", 1)
        if (recommended.length > 0) return recommended[0]
        if (root.runnableModelList.length > 0) return root.runnableModelList[0]
        if (saved && root.models[saved]) return saved
        if (root.currentModelId && root.models[root.currentModelId]) return root.currentModelId
        return root.modelList[0] ?? ""
    }

    function _syncCurrentModel(): void {
        const resolved = root._resolvedCurrentModelId()
        if (resolved !== root.currentModelId) root.currentModelId = resolved
    }

    property var apiStrategies: {
        "openai": openaiApiStrategy.createObject(this),
        "openai-response": openaiResponseApiStrategy.createObject(this),
        "gemini": geminiApiStrategy.createObject(this),
        "mistral": mistralApiStrategy.createObject(this),
        "anthropic": anthropicApiStrategy.createObject(this),
    }
    property ApiStrategy currentApiStrategy: apiStrategies[models[currentModelId]?.api_format || "openai"]

    property var _loadedExtraModelIds: []
    property var _loadedCatalogModelIds: []
    property string _extraModelsSignature: ""

    readonly property var profileDefinitions: [
        { id: "auto", name: Translation.tr("Auto"), icon: "auto_awesome", description: Translation.tr("Choose a compatible model for each request") },
        { id: "fast", name: Translation.tr("Fast"), icon: "bolt", description: Translation.tr("Prefer low-latency models") },
        { id: "quality", name: Translation.tr("Quality"), icon: "workspace_premium", description: Translation.tr("Prefer stronger reasoning and larger context") },
        { id: "free", name: Translation.tr("Free"), icon: "money_off", description: Translation.tr("Use models currently marked free") },
        { id: "private", name: Translation.tr("Private"), icon: "shield_lock", description: Translation.tr("Use local models only") },
        { id: "coding", name: Translation.tr("Coding"), icon: "code", description: Translation.tr("Prefer code-focused and tool-capable models") },
        { id: "vision", name: Translation.tr("Vision"), icon: "image", description: Translation.tr("Require image input") },
        { id: "long-context", name: Translation.tr("Long context"), icon: "article", description: Translation.tr("Prefer the largest available context window") },
    ]

    function _syncExtraModels() {
        if (!Config.ready) return
        const policy = Config.options?.policies?.ai ?? 0
        const extraModels = Config.options?.ai?.extraModels ?? []
        const liveProviders = [...new Set((AiProviderCatalog.models ?? [])
            .map(model => model.providerId).filter(id => id && id.length > 0))].sort()
        // onConfigChanged fires on every global save. Rebuilding on each one
        // recreated every AiModel; catalog provider membership matters because
        // a guided connection entry becomes fallback-only once live models load.
        const signature = policy + "|" + JSON.stringify(extraModels)
            + "|" + JSON.stringify(liveProviders)
        if (signature === root._extraModelsSignature) return
        root._extraModelsSignature = signature

        root._loadedExtraModelIds.forEach(id => {
            const old = root.models[id]
            if (!old) return
            delete root.models[id]
            old.destroy()
        })
        root._loadedExtraModelIds = []
        extraModels.forEach(model => {
            if (policy === 2 && !(model?.endpoint ?? "").includes("localhost")) return
            const providerId = model?.provider_id ?? ""
            if (providerId.length > 0 && liveProviders.includes(providerId)) return

            // Guided provider rows are connection records, not authoritative
            // model definitions. Use the current preset as a safe offline
            // fallback so old hardcoded IDs/endpoints cannot leak back in.
            const preset = providerId.length > 0 ? AiProviderPresets.byId(providerId) : null
            const resolvedModel = preset
                ? Object.assign({}, model, AiProviderPresets.toModelEntry(preset), {
                    key_id: model?.key_id ?? preset.keyId ?? "",
                })
                : model
            const safeModelName = root.safeModelName(resolvedModel["model"])
            root.addModel(safeModelName, resolvedModel)
            root._loadedExtraModelIds.push(safeModelName)
        })
        root.modelList = Object.keys(root.models)
        root._syncCurrentModel()
    }

    function _catalogModelId(entry) {
        const remoteId = root.safeModelName(entry?.remoteId ?? "")
        if ((entry?.providerId ?? "") === "ollama") return remoteId
        if ((entry?.providerId ?? "") === "openrouter") return "openrouter-" + remoteId
        return root.safeModelName((entry?.providerId ?? "catalog") + "-" + remoteId)
    }

    function _syncCatalogModels() {
        const policy = Config.options?.policies?.ai ?? 0
        root._loadedCatalogModelIds.forEach(id => {
            const old = root.models[id]
            if (!old) return
            delete root.models[id]
            old.destroy()
        })
        root._loadedCatalogModelIds = []

        const providerCounts = ({})
        for (const entry of (AiProviderCatalog.models ?? [])) {
            if (policy === 2 && !entry.local) continue
            const provider = AiProviderCatalog.providerById(entry.providerId)
            const state = AiProviderCatalog.stateFor(entry.providerId)
            // Public catalogs stay visible even before connection. Runnable
            // state is evaluated separately from catalog visibility.
            const id = root._catalogModelId(entry)
            if (!id || (root.models[id] && !root._loadedCatalogModelIds.includes(id))) continue
            providerCounts[entry.providerId] = (providerCounts[entry.providerId] ?? 0) + 1
            root.addModel(id, {
                name: entry.displayName ?? entry.remoteId,
                icon: provider?.icon ?? root.guessModelLogo(entry.remoteId ?? ""),
                description: entry.description?.length > 0
                    ? entry.description
                    : Translation.tr("Live model from %1").arg(provider?.name ?? entry.providerId),
                homepage: entry.providerId === "openrouter"
                    ? `https://openrouter.ai/${entry.remoteId}`
                    : (provider?.keyGetLink ?? ""),
                endpoint: entry.endpoint,
                model: entry.remoteId,
                requires_key: !!entry.requiresKey,
                key_id: entry.keyId ?? provider?.keyId ?? "",
                key_get_link: provider?.keyGetLink ?? "",
                key_get_description: provider?.description ?? "",
                api_format: entry.apiFormat ?? provider?.api_format ?? "openai",
                auth_scheme: entry.authScheme ?? provider?.authScheme ?? "strategy",
                provider_id: entry.providerId ?? "catalog",
                local: !!entry.local,
                free: !!entry.free,
                input_modalities: entry.inputModalities ?? ["text"],
                output_modalities: entry.outputModalities ?? ["text"],
                capabilities: entry.capabilities ?? ({}),
                context_tokens: entry.contextTokens ?? 0,
                max_output_tokens: entry.maxOutputTokens ?? 0,
                pricing: entry.pricing ?? ({}),
                expires_at: entry.expiresAt ?? "",
                catalog_status: state.status ?? "available",
                catalog_source: entry.source ?? "live",
                catalog_public: !!provider?.publicCatalog,
                refreshed_at: state.fetchedAt ?? 0,
            })
            root._loadedCatalogModelIds.push(id)
        }
        root.modelList = Object.keys(root.models)
        // Prefer the persisted model whenever it becomes runnable, but never
        // rewrite persistence merely because catalog discovery is still racing.
        root._syncCurrentModel()
    }

    function _profileAllows(model, profileId) {
        if (!model) return false
        const caps = model.capabilities ?? ({})
        if (profileId === "free" && !model.free) return false
        if (profileId === "private" && !model.local) return false
        if (profileId === "vision" && caps.vision !== "supported") return false
        if (profileId === "coding") {
            const label = `${model.model} ${model.name}`.toLowerCase()
            if (!(caps.toolCalling === "supported" || /code|coder|devstral|codestral/.test(label))) return false
        }
        return true
    }

    function _profileScore(model, profileId) {
        const caps = model.capabilities ?? ({})
        const label = `${model.model} ${model.name}`.toLowerCase()
        let score = 0
        if (model.local) score += profileId === "private" ? 1000 : 20
        if (model.free) score += profileId === "free" ? 1000 : 15
        if (caps.toolCalling === "supported") score += profileId === "coding" ? 120 : 10
        if (caps.reasoning === "supported") score += profileId === "quality" ? 100 : 8
        if (caps.vision === "supported") score += profileId === "vision" ? 300 : 4
        if (/flash|mini|small|nano|fast/.test(label)) score += profileId === "fast" ? 120 : 3
        if (/code|coder|devstral|codestral/.test(label)) score += profileId === "coding" ? 160 : 0
        const context = model.context_tokens ?? 0
        if (profileId === "long-context") score += Math.min(500, context / 1000)
        if (profileId === "quality") score += Math.min(200, context / 4000)
        if (model.catalog_status === "ready" || model.catalog_status === "available") score += 10
        return score
    }

    function recommendedModelIds(profileId = "auto", limit = 8) {
        return root.runnableModelList
            .map(id => ({ id, model: root.models[id] }))
            .filter(item => root._profileAllows(item.model, profileId))
            .sort((a, b) => root._profileScore(b.model, profileId) - root._profileScore(a.model, profileId))
            .slice(0, Math.max(1, limit))
            .map(item => item.id)
    }

    Connections {
        target: Config
        function onReadyChanged() { root._syncExtraModels() }
        function onConfigChanged() { root._syncExtraModels() }
    }

    Connections {
        target: AiProviderCatalog
        function onCatalogUpdated() {
            root._syncExtraModels()
            root._syncCatalogModels()
        }
    }

    property string requestScriptFilePath: "/tmp/quickshell/ai/request.sh"
    property string pendingFilePath: ""

    function ensureInitialized(): void {
        if (root._initialized)
            return;
        root._initialized = true;

        root._syncExtraModels()
        AiProviderCatalog.ensureInitialized()
        root._syncCatalogModels()
        getDefaultPrompts.running = true
        getUserPrompts.running = true
        getSavedChats.running = true

        // Do necessary setup for model
        setModel(currentModelId, false, false);
    }

    // Retry pending request when API keys finish loading
    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded && root._pendingRequest) {
                root._pendingRequest = false;
                requester.makeRequest();
            }
        }
    }

    Component.onCompleted: {
        // Lazy: initialize only when UI actually uses the AI service.
    }

    function guessModelLogo(model) {
        if (model.includes("llama")) return "ollama-symbolic";
        if (model.includes("gemma")) return "google-gemini-symbolic";
        if (model.includes("deepseek")) return "deepseek-symbolic";
        if (/^phi\d*:/i.test(model)) return "microsoft-symbolic";
        return "ollama-symbolic";
    }

    function guessModelName(model) {
        const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
        let words = replaced.split(' ');
        words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`)
        words = words.map((word) => {
            return (word.charAt(0).toUpperCase() + word.slice(1))
        });
        if (words[words.length - 1] === "Latest") words.pop();
        else words[words.length - 1] = `(${words[words.length - 1]})`; // Surround the last word with square brackets
        const result = words.join(' ');
        return result;
    }

    function addModel(modelName, data) {
        root.models[modelName] = aiModelComponent.createObject(this, data);
    }

    Process {
        id: getDefaultPrompts
        running: false
        command: ["/usr/bin/ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getUserPrompts
        running: false
        command: ["/usr/bin/ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: false
        command: ["/usr/bin/ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.setNestedValue(["ai", "systemPrompt"], promptLoader.text())
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options?.ai?.systemPrompt ?? ""), root.interfaceRole);
        }
    }

    function printPrompt() {
        root.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(Config.options?.ai?.systemPrompt ?? ""), root.interfaceRole);
    }

    // Human-readable name of the loaded prompt (derived from its file name, e.g.
    // "ii-Default.md" → "ii-Default"). Persisted so it survives restarts.
    property string currentPromptName: Persistent.states?.ai?.promptName ?? ""

    function _promptNameFromPath(filePath) {
        const base = (filePath ?? "").split("/").pop();
        return base.replace(/\.(md|txt)$/i, "");
    }

    function loadPrompt(filePath) {
        root.currentPromptName = root._promptNameFromPath(filePath);
        if (Persistent.states?.ai) Persistent.states.ai.promptName = root.currentPromptName;
        promptLoader.path = "" // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addMessage(message, role) {
        if (message.length === 0) return;
        if (role === root.interfaceRole) root._lastInterfaceMessage = message;
        const aiMessage = aiMessageComponent.createObject(root, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= messageIDs.length) return;
        const id = root.messageIDs[index];
        root.messageIDs.splice(index, 1);
        root.messageIDs = [...root.messageIDs];
        root.messageByID[id]?.destroy();
        delete root.messageByID[id];
    }

    function addApiKeyAdvice(model) {
        const provider = AiProviderCatalog.providerById(model?.provider_id ?? "")
        root.addMessage(
            Translation.tr("%1 is available in the live catalog, but %2 is not connected. Open Settings → AI to add or update its API key.\n\n%3")
                .arg(model?.name ?? Translation.tr("This model"))
                .arg(provider?.name ?? model?.provider_id ?? Translation.tr("the provider"))
                .arg(model?.key_get_link ?? ""),
            root.interfaceRole
        )
    }

    function getModel() {
        return models[currentModelId];
    }

    function setModel(modelId, feedback = true, setPersistentState = true): bool {
        if (!modelId) modelId = ""
        modelId = modelId.toLowerCase()
        if (root.modelList.indexOf(modelId) === -1) {
            if (feedback) root.addMessage(Translation.tr("Model not found in the current catalog."), root.interfaceRole)
            return false
        }

        const model = root.models[modelId]
        if ((Config.options?.policies?.ai ?? 0) === 2 && !model.local) {
            if (feedback) root.addMessage(
                Translation.tr("Online models are disabled by the current AI privacy policy."),
                root.interfaceRole
            )
            return false
        }
        if (!root.modelCanRun(model)) {
            if (feedback) root.addApiKeyAdvice(model)
            return false
        }

        root.currentModelId = modelId
        if (setPersistentState && Persistent.states?.ai)
            Persistent.states.ai.model = modelId
        if (feedback) root.addMessage(Translation.tr("Model set to %1").arg(model.name), root.interfaceRole)
        return true
    }

    function setTool(tool) {
        const model = models[currentModelId]
        if (!model) {
            root.addMessage(
                Translation.tr("No model selected\n\nUse /model to pick one"),
                root.interfaceRole
            )
            return false;
        }
        const fmt = model.api_format
        if (!root.tools[fmt] || !root.availableTools.includes(tool)) {
            root.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1")
                .arg(root.availableTools ? root.availableTools.join("\n- ") : ""), root.interfaceRole)
            return false
        }
        Config.setNestedValue(["ai", "tool"], tool)
        return true
    }
    
    function getTemperature() {
        return root.temperature;
    }

    function setTemperature(value) {
        const num = Number(value)
        if (Number.isNaN(num)) {
            root.addMessage(Translation.tr("Temperature must be a number"), Ai.interfaceRole);
            return;
        }
        const model = models[currentModelId]
        const max = (model?.api_format === "gemini") ? 2 : 1
        if (num < 0 || num > max) {
            root.addMessage(Translation.tr("Temperature must be between 0 and %1").arg(max), Ai.interfaceRole);
            return;
        }

        Persistent.states.ai.temperature = num;
        root.temperature = num;
        root.addMessage(Translation.tr("Temperature set to %1").arg(num), Ai.interfaceRole);
    }

    function setApiKey(key) {
        const model = models[currentModelId];
        if (!model) {
            root.addMessage(
                Translation.tr("No model selected\n\nUse /model to pick one"),
                root.interfaceRole
            )
            return;
        }
        if (!model.requires_key) {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            const model = models[currentModelId];
            root.addApiKeyAdvice(model)
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim())
        if ((model.provider_id ?? "").length > 0)
            Qt.callLater(() => AiProviderCatalog.refreshProvider(model.provider_id))
        root.addMessage(Translation.tr("API key stored for %1").arg(model.name), root.interfaceRole)
    }

    function printApiKey() {
        const model = models[currentModelId];
        if (!model) {
            root.addMessage(
                Translation.tr("No model selected\n\nUse /model to pick one"),
                root.interfaceRole
            )
            return;
        }
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id]
            root.addMessage(key
                ? Translation.tr("An API key is stored for %1.").arg(model.name)
                : Translation.tr("No API key is stored for %1.").arg(model.name), root.interfaceRole)
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
        }
    }

    function authorizationHeaderForModel(model, strategy): string {
        if (!model?.requires_key) return ""
        switch (model.auth_scheme ?? "strategy") {
        case "none":
        case "gemini-query":
            return ""
        case "bearer":
            return `-H "Authorization: Bearer \$\{${root.apiKeyEnvVarName}\}"`
        case "anthropic":
            return `-H "x-api-key: \$\{${root.apiKeyEnvVarName}\}" -H "anthropic-version: 2023-06-01"`
        case "gemini-header":
            return `-H "x-goog-api-key: \$\{${root.apiKeyEnvVarName}\}"`
        default:
            return strategy.buildAuthorizationHeader(root.apiKeyEnvVarName)
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }

    function clearMessages() {
        for (const id of root.messageIDs) {
            root.messageByID[id]?.destroy();
        }
        root.messageIDs = [];
        root.messageByID = ({});
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    FileView {
        id: requesterScriptFile
    }

    Process {
        id: requester
        property list<string> baseCommand: ["/usr/bin/bash"]
        property AiMessageData message
        property ApiStrategy currentStrategy
        property int httpStatus: 0

        property bool _restartQueued: false

        function markDone() {
            requester.message.done = true;
            // A tool-call continuation is queued: this isn't the final
            // response yet, so the hook/save/signal wait for it
            if (requester._restartQueued) return;
            if (root.postResponseHook) {
                root.postResponseHook();
                root.postResponseHook = null; // Reset hook after use
            }
            root.saveChat("lastSession")
            root.responseFinished()
        }

        function makeRequest() {
            // Called mid-stream by tool-call continuations: setting running
            // on a live process is a no-op and would silently drop the
            // follow-up request, so queue it for onExited instead
            if (requester.running) {
                requester._restartQueued = true;
                return;
            }
            const model = models[currentModelId];

            if (!model) {
                root.addMessage(
                    Translation.tr("No model selected\n\nUse /model to pick one (or enable AI / local models in settings)"),
                    root.interfaceRole
                )
                return
            }

            // Resolve the stored provider key first. Zen free models use the
            // same public credential fallback as the official OpenCode client.
            if (model?.requires_key && !KeyringStorage.loaded) {
                KeyringStorage.fetchKeyringData()
                root._pendingRequest = true
                return
            }
            const apiKey = root.credentialForModel(model)
            if (model?.requires_key && apiKey.length === 0) {
                root.addApiKeyAdvice(model)
                return
            }

            requester.currentStrategy = root.currentApiStrategy
            if (!requester.currentStrategy) {
                root.addMessage(
                    Translation.tr("The selected model uses an API protocol that iNiR does not support yet."),
                    root.interfaceRole
                )
                return
            }
            requester.currentStrategy.reset()
            requester.httpStatus = 0

            // Replace the environment object so a key from the previous model
            // cannot survive a switch to a local or differently keyed provider.
            requester.environment = model?.requires_key
                ? ({ [root.apiKeyEnvVarName]: apiKey }) : ({})

            /* Build endpoint, request data */
            const endpoint = root.currentApiStrategy.buildEndpoint(model);
            const messageArray = root.messageIDs.map(id => root.messageByID[id]);
            const filteredMessageArray = messageArray.filter(message =>
                message.role !== Ai.interfaceRole && !message.requestFailed)
            const data = root.currentApiStrategy.buildRequestData(model, filteredMessageArray, root.systemPrompt, root.temperature, root.toolsForRequest(model.api_format, root.currentTool), root.pendingFilePath);
            // console.log("[Ai] Request data: ", JSON.stringify(data, null, 2));

            let requestHeaders = {
                "Content-Type": "application/json",
            }
            
            /* Create local message object */
            requester.message = root.aiMessageComponent.createObject(root, {
                "role": "assistant",
                "model": currentModelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = idForMessage(requester.message);
            root.messageIDs = [...root.messageIDs, id];
            root.messageByID[id] = requester.message;

            /* Build header string for curl */ 
            let headerString = Object.entries(requestHeaders)
                .filter(([k, v]) => v && v.length > 0)
                .map(([k, v]) => `-H '${k}: ${v}'`)
                .join(' ');

            // console.log("Request headers: ", JSON.stringify(requestHeaders));
            // console.log("Header string: ", headerString);

            /* Get authorization header from strategy. Only send it when the
               model actually uses a key — otherwise the API_KEY env var is
               unset and we'd send an empty `Authorization: Bearer `, which
               local/keyless endpoints (e.g. Ollama) reject with a missing-auth
               error. */
            const authHeader = root.authorizationHeaderForModel(model, requester.currentStrategy)

            /* Script shebang */
            const scriptShebang = "#!/usr/bin/env bash\n";

            /* Create extra setup when there's an attached file */
            let scriptFileSetupContent = ""
            if (root.pendingFilePath && root.pendingFilePath.length > 0) {
                requester.message.localFilePath = root.pendingFilePath;
                scriptFileSetupContent = requester.currentStrategy.buildScriptFileSetup(root.pendingFilePath);
                root.pendingFilePath = ""
            }

            /* Create command string. The payload goes through the printf
               builtin into curl's stdin: as a curl argument it hits the
               kernel's per-argument exec limit (~128 KiB) on large payloads
               (e.g. get_shell_config output), killing the request silently. */
            let scriptRequestContent = ""
            const curlStatusToken = String.fromCharCode(37) + "{http_code}"
            scriptRequestContent += `printf '%s' '${CF.StringUtils.shellSingleQuoteEscape(JSON.stringify(data))}'`
                + ` | curl -sS --no-buffer "${endpoint}"`
                + ` ${headerString}`
                + (authHeader ? ` ${authHeader}` : "")
                + ` --data @-`
                + ` --write-out '\n__INIR_HTTP_STATUS__:${curlStatusToken}\n'`
                + "\n"
            
            /* Send the request */
            const scriptContent = requester.currentStrategy.finalizeScriptContent(scriptShebang + scriptFileSetupContent + scriptRequestContent)
            const shellScriptPath = CF.FileUtils.trimFileProtocol(root.requestScriptFilePath)
            requesterScriptFile.path = Qt.resolvedUrl(shellScriptPath)
            requesterScriptFile.setText(scriptContent)
            requester.command = baseCommand.concat([shellScriptPath]);
            // Setting running=true from inside this Process's own onExited
            // handler is silently dropped — start on the next event-loop turn
            Qt.callLater(() => { requester.running = true; });
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return
                if (data.startsWith("__INIR_HTTP_STATUS__:")) {
                    requester.httpStatus = Number(data.substring("__INIR_HTTP_STATUS__:".length).trim()) || 0
                    return
                }
                if (requester.message.thinking) requester.message.thinking = false;
                _log("[Ai] Raw response line: ", data.substring(0, 100));

                // Handle response line
                try {
                    const result = requester.currentStrategy.parseResponseLine(data, requester.message);
                    // console.log("[Ai] Parsed response result: ", JSON.stringify(result, null, 2));

                    if (result.functionCall) {
                        requester.message.functionCall = result.functionCall;
                        root.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                    }
                    if (result.tokenUsage) {
                        root.tokenCount.input = result.tokenUsage.input;
                        root.tokenCount.output = result.tokenUsage.output;
                        root.tokenCount.total = result.tokenUsage.total;
                    }
                    if (result.finished) {
                        requester.markDone();
                    }
                    
                } catch (e) {
                    console.log("[AI] Could not parse response: ", e);
                    requester.message.rawContent += data;
                    requester.message.content += data;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            const finishedMessage = requester.message;
            const result = requester.currentStrategy.onRequestFinished(finishedMessage);

            // A tool call flushed at end-of-stream still needs handling
            if (result.functionCall) {
                finishedMessage.functionCall = result.functionCall;
                root.handleFunctionCall(result.functionCall.name, result.functionCall.args, finishedMessage);
            }

            if (requester._restartQueued) {
                requester._restartQueued = false;
                finishedMessage.done = true;
                requester.makeRequest();
                return;
            }
            // handleFunctionCall above may have started the continuation
            // directly (process already exited) — don't touch the new message
            if (requester.message !== finishedMessage) {
                finishedMessage.done = true;
                return;
            }

            if (!finishedMessage.done) {
                requester.markDone();
            }

            // Normalize error responses
            if (requester.httpStatus === 401 || requester.httpStatus === 403) {
                const failedModel = root.models[finishedMessage.model]
                const providerId = failedModel?.provider_id ?? ""
                const providerName = AiProviderCatalog.providerById(providerId)?.name
                    ?? providerId ?? Translation.tr("this provider")
                const responseDetail = String(finishedMessage.rawContent ?? "").trim()
                const summary = requester.httpStatus === 401
                    ? Translation.tr("%1 returned HTTP 401 for this request. The credential, account/model access, or selected API route may be the cause; iNiR kept the stored key unchanged.").arg(providerName)
                    : Translation.tr("%1 denied access to this request (HTTP 403). Check model/account permissions; iNiR kept the stored key unchanged.").arg(providerName)
                const message = responseDetail.length > 0
                    ? summary + "\n\n" + responseDetail.substring(0, 600)
                    : summary
                finishedMessage.content = message
                finishedMessage.rawContent = message
                finishedMessage.role = root.interfaceRole
                finishedMessage.requestFailed = true
                finishedMessage.thinking = false
                finishedMessage.done = true
            } else if (requester.httpStatus === 429) {
                const failedModel = root.models[finishedMessage.model]
                const providerName = AiProviderCatalog.providerById(failedModel?.provider_id ?? "")?.name
                    ?? Translation.tr("The provider")
                const message = Translation.tr("%1 is rate limited right now. Wait briefly or select another available model.")
                    .arg(providerName)
                finishedMessage.content = message
                finishedMessage.rawContent = message
                finishedMessage.thinking = false
                finishedMessage.done = true
            } else if (requester.httpStatus >= 400) {
                const failedModel = root.models[finishedMessage.model]
                const providerName = AiProviderCatalog.providerById(failedModel?.provider_id ?? "")?.name
                    ?? Translation.tr("The provider")
                const responseDetail = String(finishedMessage.rawContent ?? "").trim()
                const summary = requester.httpStatus === 404
                    ? Translation.tr("%1 no longer exposes this model or endpoint. Refresh the catalog and select another model.").arg(providerName)
                    : requester.httpStatus >= 500
                        ? Translation.tr("%1 is temporarily unavailable (HTTP %2).").arg(providerName).arg(requester.httpStatus)
                        : Translation.tr("%1 rejected this request (HTTP %2). The response below identifies the rejected payload field or model capability.")
                            .arg(providerName).arg(requester.httpStatus)
                const message = responseDetail.length > 0
                    ? summary + "\n\n" + responseDetail.substring(0, 1000)
                    : summary
                finishedMessage.content = message
                finishedMessage.rawContent = message
                finishedMessage.role = root.interfaceRole
                finishedMessage.requestFailed = true
                finishedMessage.thinking = false
                finishedMessage.done = true
            }
            if (requester.httpStatus >= 400) root.saveChat("lastSession")
        }
    }

    // Whether a response is currently being generated (UI: stop button)
    readonly property bool busy: requester.running

    function stopRequest() {
        if (!requester.running) return;
        requester._restartQueued = false;
        requester.signal(15);
    }

    function sendUserMessage(message): bool {
        if (message.length === 0) return false
        const model = root.models[root.currentModelId]
        if (!model) {
            root.addMessage(
                Translation.tr("Select an available model before sending a message."),
                root.interfaceRole
            )
            return false
        }
        if (!root.modelCanRun(model)) {
            root.addApiKeyAdvice(model)
            return false
        }
        root.addMessage(message, "user")
        requester.makeRequest()
        return true
    }

    function attachFile(filePath: string) {
        root.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= messageIDs.length) return;
        const id = root.messageIDs[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant") return;
        // Remove all messages after this one
        for (let i = root.messageIDs.length - 1; i >= messageIndex; i--) {
            root.removeMessage(i);
        }
        requester.makeRequest();
    }

    function createFunctionOutputMessage(name, output, includeOutputInChat = true, callId = "") {
        return aiMessageComponent.createObject(root, {
            "role": "user",
            "content": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "rawContent": `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`,
            "functionName": name,
            "functionResponse": output,
            // Carries the originating call id so strategies can echo the
            // exact tool_call_id — providers reject mismatched ids
            "functionCall": (callId && callId.length > 0) ? { "id": callId, "name": name } : undefined,
            "thinking": false,
            "done": true,
            // "visibleToUser": false,
        });
    }

    function addFunctionOutputMessage(name, output, callId = "") {
        const aiMessage = createFunctionOutputMessage(name, output, true, callId);
        const id = idForMessage(aiMessage);
        root.messageIDs = [...root.messageIDs, id];
        root.messageByID[id] = aiMessage;
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending) return
        message.functionPending = false
        addFunctionOutputMessage(message.functionName,
            Translation.tr("Action rejected by user"), message.functionCall?.id ?? "")
    }

    function _parseConfigToolValue(value): var {
        if (typeof value !== "string") return value
        const trimmed = value.trim()
        if (trimmed.length === 0) return ""
        try {
            return JSON.parse(trimmed)
        } catch (error) {
            return value
        }
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending) return
        message.functionPending = false

        if (message.functionName === "set_shell_config") {
            const args = message.functionCall?.args ?? ({})
            const value = root._parseConfigToolValue(args.value)
            Config.setNestedValue(args.key, value)
            addFunctionOutputMessage(message.functionName,
                Translation.tr("Applied `%1` with value `%2`.")
                    .arg(args.key).arg(JSON.stringify(value)),
                message.functionCall?.id ?? "")
            requester.makeRequest()
            return
        }

        if (message.functionName === "run_shell_action") {
            const args = message.functionCall?.args ?? ({})
            const action = root._aiSafeActions("").find(item => item.id === args.action_id)
            const success = action ? GlobalActions.runById(args.action_id, args.args ?? "") : false
            addFunctionOutputMessage(message.functionName,
                success
                    ? Translation.tr("Shell action `%1` completed.").arg(args.action_id)
                    : Translation.tr("Shell action `%1` is unavailable or not allowed.").arg(args.action_id),
                message.functionCall?.id ?? "")
            requester.makeRequest()
            return
        }

        const responseMessage = createFunctionOutputMessage(
            message.functionName, "", false, message.functionCall?.id ?? "")
        const id = idForMessage(responseMessage)
        root.messageIDs = [...root.messageIDs, id]
        root.messageByID[id] = responseMessage

        commandExecutionProc.message = responseMessage
        commandExecutionProc.baseMessageContent = responseMessage.content
        commandExecutionProc.shellCommand = message.functionCall.args.command
        commandExecutionProc.running = true
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        command: ["/usr/bin/bash", "-c", shellCommand]
        stdout: SplitParser {
            onRead: (output) => {
                commandExecutionProc.message.functionResponse += output + "\n\n";
                root._log("[Ai] commandExecutionProc output:", output)
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
            requester.makeRequest(); // Continue
        }
    }

    function _aiSafeActions(query: string): var {
        const allowedCategories = ["appearance", "media", "settings", "tools"]
        const source = query && query.trim().length > 0
            ? GlobalActions.fuzzyQuery(query) : GlobalActions.allActions
        return source.filter(action => allowedCategories.includes(action.category)).slice(0, 40)
    }

    function handleFunctionCall(name, args: var, message: AiMessageData) {
        const callId = message?.functionCall?.id ?? "";
        if (name === "switch_to_search_mode") {
            root._toolOverride = "search"
            root.postResponseHook = () => { root._toolOverride = "" }
            addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."), callId)
            requester.makeRequest();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options)
            addFunctionOutputMessage(name, JSON.stringify(configJson), callId)
            requester.makeRequest()
        } else if (name === "get_shell_actions") {
            const actions = root._aiSafeActions(args?.query ?? "").map(action => ({
                id: action.id,
                name: action.name,
                description: action.description,
                category: action.category,
            }))
            addFunctionOutputMessage(name, JSON.stringify(actions), callId)
            requester.makeRequest()
        } else if (name === "run_shell_action") {
            const actionId = String(args?.action_id ?? "")
            const action = root._aiSafeActions("").find(item => item.id === actionId)
            if (!action) {
                addFunctionOutputMessage(name,
                    Translation.tr("Unknown or disallowed shell action: %1").arg(actionId), callId)
                requester.makeRequest()
                return
            }
            const preview = {
                action: "run_shell_action",
                id: action.id,
                name: action.name,
                description: action.description,
                args: args?.args ?? "",
            }
            const contentToAppend = "\n\n**Shell action request**\n\n```approval\n"
                + JSON.stringify(preview, null, 2) + "\n```"
            message.rawContent += contentToAppend
            message.content += contentToAppend
            message.functionPending = true
        } else if (name === "set_shell_config") {
            if (!args.key || args.value === undefined) {
                addFunctionOutputMessage(name,
                    Translation.tr("Invalid arguments. Must provide `key` and `value`."), callId)
                requester.makeRequest()
                return
            }
            const oldValue = Config.getNestedValue(args.key, null)
            const newValue = root._parseConfigToolValue(args.value)
            const preview = {
                action: "set_shell_config",
                key: args.key,
                previous: oldValue,
                proposed: newValue,
                valueType: typeof newValue,
            }
            const contentToAppend = "\n\n**Configuration change request**\n\n```approval\n"
                + JSON.stringify(preview, null, 2) + "\n```"
            message.rawContent += contentToAppend
            message.content += contentToAppend
            message.functionPending = true
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."), callId);
                requester.makeRequest();
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true; // Use thinking to indicate the command is waiting for approval
        } else {
            addFunctionOutputMessage(name, Translation.tr("Unknown function: %1").arg(name), callId);
            requester.makeRequest();
        }
    }

    function chatToJson() {
        return root.messageIDs.map(id => {
            const message = root.messageByID[id]
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
            })
        })
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatName.length > 0 ? `${Directories.aiChats}/${chatName}.json` : ""
        blockLoading: true // Prevent race conditions
    }

    /**
     * Saves chat to a JSON list of message objects.
     * @param chatName name of the chat
     */
    function saveChat(chatName) {
        chatSaveFile.chatName = chatName.trim()
        const saveContent = JSON.stringify(root.chatToJson())
        chatSaveFile.setText(saveContent)
        getSavedChats.running = true;
    }

    Process {
        id: chatFileOps
        onExited: getSavedChats.running = true
    }

    function chatPathForName(chatName) {
        return `${Directories.aiChats}/${chatName.trim()}.json`;
    }

    function deleteChat(chatName) {
        if (!chatName || chatName.trim().length === 0) return;
        chatFileOps.exec(["/usr/bin/rm", "-f", "--", chatPathForName(chatName)]);
    }

    function renameChat(oldName, newName) {
        if (!oldName || !newName) return;
        const clean = newName.trim().replace(/[\/\0]/g, "-");
        if (clean.length === 0 || clean === oldName.trim()) return;
        chatFileOps.exec(["/usr/bin/mv", "--", chatPathForName(oldName), chatPathForName(clean)]);
    }

    // Stash the current conversation under a timestamped name, then clear
    function newChat() {
        if (root.messageIDs.length > 0) {
            const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm");
            root.saveChat(`chat-${stamp}`);
        }
        root.clearMessages();
    }

    /**
     * Loads chat from a JSON list of message objects.
     * @param chatName name of the chat
     */
    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim()
            chatSaveFile.reload()
            const saveContent = chatSaveFile.text()
            // console.log(saveContent)
            const saveData = JSON.parse(saveContent)
            root.clearMessages()
            root.messageIDs = saveData.map((_, i) => {
                return i
            })
            // console.log(JSON.stringify(messageIDs))
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                root.messageByID[i] = root.aiMessageComponent.createObject(root, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser,
                });
            }
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        } finally {
            getSavedChats.running = true;
        }
    }
}
