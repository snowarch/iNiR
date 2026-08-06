import QtQuick

ApiStrategy {
    property bool isReasoning: false
    // Streamed tool calls arrive as fragments (name in the first delta,
    // arguments split across many) — accumulate per index, flush on finish.
    property var pendingToolCalls: ({})
    property bool hasPendingToolCalls: false

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                ...(systemPrompt && systemPrompt.length > 0 ? [{role: "system", content: systemPrompt}] : []),
                ...messages.map(message => {
                    const isToolResult = (message.functionResponse?.length > 0) && (message.functionName?.length > 0);
                    if (isToolResult) {
                        return {
                            "role": "tool",
                            "content": message.functionResponse,
                            "tool_call_id": message.functionCall?.id ?? message.functionName,
                        };
                    }
                    const isToolCall = message.role === "assistant"
                        && message.functionCall && typeof message.functionCall === "object"
                        && (message.functionCall.name?.length > 0);
                    if (isToolCall) {
                        return {
                            "role": "assistant",
                            "content": message.rawContent,
                            "tool_calls": [{
                                "id": message.functionCall.id ?? message.functionCall.name,
                                "type": "function",
                                "function": {
                                    "name": message.functionCall.name,
                                    "arguments": JSON.stringify(message.functionCall.args ?? {}),
                                }
                            }],
                        };
                    }
                    return {
                        "role": message.role,
                        "content": message.rawContent,
                    };
                }),
            ],
            "stream": true,
            "temperature": temperature,
        };
        // Some providers reject an empty tools array outright
        if (tools && tools.length > 0) baseData.tools = tools;
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function flushPendingToolCall(message) {
        const indices = Object.keys(pendingToolCalls);
        if (indices.length === 0) return {};
        const call = pendingToolCalls[indices[0]];
        pendingToolCalls = {};
        hasPendingToolCalls = false;
        let args = {};
        try {
            args = call.args.length > 0 ? JSON.parse(call.args) : {};
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse tool call arguments: ", e);
        }
        const newContent = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
        message.rawContent += newContent;
        message.content += newContent;
        message.functionName = call.name;
        return { functionCall: { name: call.name, args: args, id: call.id } };
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            if (hasPendingToolCalls) return Object.assign({ finished: true }, flushPendingToolCall(message));
            return { finished: true };
        }

        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            const choice = dataJson.choices?.[0];

            // Tool call fragments
            if (choice?.delta?.tool_calls) {
                for (const toolCall of choice.delta.tool_calls) {
                    const idx = toolCall.index ?? 0;
                    if (!pendingToolCalls[idx]) pendingToolCalls[idx] = { id: "", name: "", args: "" };
                    if (toolCall.id) pendingToolCalls[idx].id = toolCall.id;
                    if (toolCall.function?.name) pendingToolCalls[idx].name += toolCall.function.name;
                    if (toolCall.function?.arguments) pendingToolCalls[idx].args += toolCall.function.arguments;
                }
                hasPendingToolCalls = true;
                return {};
            }
            if (choice?.finish_reason && hasPendingToolCalls) {
                return flushPendingToolCall(message);
            }

            let newContent = "";

            const responseContent = choice?.delta?.content || dataJson.message?.content;
            const responseReasoning = choice?.delta?.reasoning || choice?.delta?.reasoning_content;

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                return { finished: true };
            }

        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }

        return {};
    }

    function onRequestFinished(message) {
        if (hasPendingToolCalls) return flushPendingToolCall(message);
        return {};
    }

    function reset() {
        isReasoning = false;
        pendingToolCalls = {};
        hasPendingToolCalls = false;
    }

}
