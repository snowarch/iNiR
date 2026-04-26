import QtQuick

ApiStrategy {
    property string currentEvent: ""
    property bool isThinking: false

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let data = {
            "model": model.model,
            "max_tokens": model.extraParams?.max_tokens ?? 4096,
            "messages": messages.map(message => {
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
        return {};
    }

    function reset() {
        currentEvent = "";
        isThinking = false;
    }
}
