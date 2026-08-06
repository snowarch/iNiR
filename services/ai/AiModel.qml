import QtQuick;

/**
 * An AI model representation.
 * - name: Friendly name of the model
 * - icon: Icon name of the model
 * - description: Description of the model
 * - endpoint: Endpoint of the model
 * - model: Model code (like gpt-4.1 or gemini-2.5-flash)
 * - requires_key: Whether the model requires an API key
 * - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
 * - key_get_link: Link to get an API key
 * - key_get_description: Description of pricing and how to get an API key
 * - api_format: Request/response protocol used by the endpoint.
 * - auth_scheme: Authentication transport, independent from the payload protocol.
 * - extraParams: Extra parameters to be passed to the model. This is a JSON object.
 */

QtObject {
    property string name
    property string icon
    property string description
    property string homepage
    property string endpoint
    property string model
    property bool requires_key: true
    property string key_id
    property string key_get_link
    property string key_get_description
    property string api_format: "openai"
    property string auth_scheme: "strategy"
    property string provider_id: "custom"
    property bool local: endpoint.includes("localhost") || endpoint.includes("127.0.0.1")
    property bool free: local
    property list<string> input_modalities: ["text"]
    property list<string> output_modalities: ["text"]
    property var capabilities: ({
        chat: "supported",
        vision: "unknown",
        audioInput: "unknown",
        toolCalling: "unknown",
        webSearch: "unknown",
        structuredOutput: "unknown",
        reasoning: "unknown",
    })
    property int context_tokens: 0
    property int max_output_tokens: 0
    property var pricing: ({})
    property string expires_at: ""
    property string catalog_status: "available"
    property string catalog_source: "configured"
    property bool catalog_public: false
    property int refreshed_at: 0
    property var tools
    property var extraParams: ({})
}
