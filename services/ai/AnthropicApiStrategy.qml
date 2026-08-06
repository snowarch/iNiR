import QtQuick

ApiStrategy {
    property string currentEvent: ""
    property bool isThinking: false
    // tool_use input streams as input_json_delta fragments — accumulate
    // until content_block_stop
    property var pendingToolCall: null

    function buildEndpoint(model: AiModel): string {
        let ep = model.endpoint;
        if (!ep.includes("/v1/messages")) {
            ep = ep.replace(/\/+$/, "") + "/v1/messages";
        }
        return ep;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let data = {
            "model": model.model,
            "max_tokens": model.extraParams?.max_tokens ?? 4096,
            "messages": messages.map(message => {
                const isToolResult = (message.functionResponse?.length > 0) && (message.functionName?.length > 0);
                if (isToolResult) {
                    return {
                        "role": "user",
                        "content": [{
                            "type": "tool_result",
                            "tool_use_id": (typeof message.functionCall === "object" ? message.functionCall?.id : null) ?? message.functionName,
                            "content": message.functionResponse,
                        }],
                    };
                }
                const isToolCall = message.role === "assistant"
                    && message.functionCall && typeof message.functionCall === "object"
                    && (message.functionCall.name?.length > 0);
                if (isToolCall) {
                    return {
                        "role": "assistant",
                        "content": [{
                            "type": "tool_use",
                            "id": message.functionCall.id ?? message.functionCall.name,
                            "name": message.functionCall.name,
                            "input": message.functionCall.args ?? {},
                        }],
                    };
                }
                return {
                    "role": message.role,
                    "content": message.rawContent,
                };
            }),
            "stream": true,
        };

        if (systemPrompt && systemPrompt.length > 0) {
            data.system = systemPrompt;
        }

        if (temperature !== undefined) {
            data.temperature = temperature;
        }

        if (tools && tools.length > 0) {
            data.tools = tools;
        }

        return model.extraParams ? Object.assign({}, data, model.extraParams) : data;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "x-api-key: \$\{${apiKeyEnvVarName}\}" -H "anthropic-version: 2023-06-01"`;
    }

    function flushPendingToolCall(message) {
        if (!pendingToolCall) return {};
        const call = pendingToolCall;
        pendingToolCall = null;
        let args = {};
        try {
            args = call.args.length > 0 ? JSON.parse(call.args) : {};
        } catch (e) {
            console.log("[AI] Anthropic: Could not parse tool_use input: ", e);
        }
        const newContent = `\n\n[[ Function: ${call.name}(${JSON.stringify(args, null, 2)}) ]]\n`;
        message.rawContent += newContent;
        message.content += newContent;
        message.functionName = call.name;
        return { functionCall: { name: call.name, args: args, id: call.id } };
    }

    function parseResponseLine(line, message) {
        let cleanLine = line.trim();

        if (cleanLine.startsWith("event:")) {
            currentEvent = cleanLine.slice(6).trim();
            return {};
        }

        if (cleanLine.startsWith("data:")) {
            let cleanData = cleanLine.slice(5).trim();

            if (!cleanData) return {};

            try {
                const dataJson = JSON.parse(cleanData);

                switch (dataJson.type) {
                    case "message_start":
                        if (dataJson.message?.usage) {
                            return {
                                tokenUsage: {
                                    input: dataJson.message.usage.input_tokens ?? -1,
                                    output: -1,
                                    total: -1
                                }
                            };
                        }
                        break;

                    case "content_block_start":
                        if (dataJson.content_block?.type === "tool_use") {
                            pendingToolCall = {
                                id: dataJson.content_block.id ?? "",
                                name: dataJson.content_block.name ?? "",
                                args: "",
                            };
                        }
                        break;

                    case "content_block_delta":
                        const delta = dataJson.delta;
                        if (delta?.type === "text_delta" && delta.text) {
                            if (isThinking) {
                                isThinking = false;
                                message.content += "\n\n</think>\n\n";
                                message.rawContent += "\n\n</think>\n\n";
                            }
                            message.content += delta.text;
                            message.rawContent += delta.text;
                        } else if (delta?.type === "thinking_delta" && delta.thinking) {
                            if (!isThinking) {
                                isThinking = true;
                                message.rawContent += "\n\n<think>\n\n";
                                message.content += "\n\n<think>\n\n";
                            }
                            message.rawContent += delta.thinking;
                            message.content += delta.thinking;
                        } else if (delta?.type === "input_json_delta" && pendingToolCall) {
                            pendingToolCall.args += delta.partial_json ?? "";
                        }
                        break;

                    case "content_block_stop":
                        if (pendingToolCall) {
                            return flushPendingToolCall(message);
                        }
                        break;

                    case "message_delta":
                        if (dataJson.usage) {
                            return {
                                tokenUsage: {
                                    input: -1,
                                    output: dataJson.usage.output_tokens ?? -1,
                                    total: -1
                                }
                            };
                        }
                        break;

                    case "message_stop":
                        return { finished: true };

                    case "error":
                        const errorMsg = `**Error**: ${dataJson.error?.message || JSON.stringify(dataJson.error)}`;
                        message.rawContent += errorMsg;
                        message.content += errorMsg;
                        return { finished: true };
                }

            } catch (e) {
                console.log("[AI] Anthropic: Could not parse line: ", e);
                message.rawContent += cleanData;
                message.content += cleanData;
            }
        }

        return {};
    }

    function onRequestFinished(message) {
        if (pendingToolCall) return flushPendingToolCall(message);
        return {};
    }

    function reset() {
        currentEvent = "";
        isThinking = false;
        pendingToolCall = null;
    }
}
