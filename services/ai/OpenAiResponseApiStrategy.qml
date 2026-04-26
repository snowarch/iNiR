import QtQuick

ApiStrategy {
    property bool isReasoning: false

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let inputMessages = messages.map(message => {
            return {
                "role": message.role,
                "content": message.rawContent,
            };
        });

        let data = {
            "model": model.model,
            "input": inputMessages,
            "stream": true,
        };

        if (systemPrompt && systemPrompt.length > 0) {
            data.instructions = systemPrompt;
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
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        let cleanData = line.trim();

        if (cleanData.startsWith("event:")) return {};

        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        if (!cleanData || cleanData === "[DONE]") {
            if (cleanData === "[DONE]") return { finished: true };
            return {};
        }

        try {
            const dataJson = JSON.parse(cleanData);

            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            let newContent = "";

            if (dataJson.type === "response.output_text.delta") {
                if (dataJson.delta && dataJson.delta.length > 0) {
                    if (isReasoning) {
                        isReasoning = false;
                        message.content += "\n\n</think>\n\n";
                        message.rawContent += "\n\n</think>\n\n";
                    }
                    newContent = dataJson.delta;
                }
            }

            if (newContent.length > 0) {
                message.content += newContent;
                message.rawContent += newContent;
            }

            if (dataJson.type === "response.completed") {
                if (dataJson.response?.usage) {
                    return {
                        tokenUsage: {
                            input: dataJson.response.usage.input_tokens ?? -1,
                            output: dataJson.response.usage.output_tokens ?? -1,
                            total: dataJson.response.usage.total_tokens ?? -1
                        },
                        finished: true
                    };
                }
                return { finished: true };
            }

        } catch (e) {
            console.log("[AI] OpenAI Response: Could not parse line: ", e);
            message.rawContent += cleanData;
            message.content += cleanData;
        }

        return {};
    }

    function onRequestFinished(message) {
        return {};
    }

    function reset() {
        isReasoning = false;
    }
}
