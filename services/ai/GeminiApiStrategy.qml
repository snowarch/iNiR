import QtQuick
import qs.modules.common.functions as CF

ApiStrategy {
    readonly property string apiKeyEnvVarName: "API_KEY"
    readonly property string fileUriVarName: "file_uri"
    readonly property string fileMimeTypeVarName: "MIME_TYPE"
    readonly property string fileUriSubstitutionString: "{{ fileUriVarName }}"
    readonly property string fileMimeTypeSubstitutionString: "{{ fileMimeTypeVarName }}"
    property string buffer: ""
    property bool isThinking: false

    function buildEndpoint(model: AiModel): string {
        if ((model.auth_scheme ?? "strategy") === "bearer"
                || (model.auth_scheme ?? "strategy") === "gemini-header")
            return model.endpoint
        const separator = model.endpoint.includes("?") ? "&" : "?"
        return model.endpoint + separator + `key=\$\{${root.apiKeyEnvVarName}\}`
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let contents = messages.map(message => {
            // console.log("[AI] Building request data for message:", JSON.stringify(message, null, 2));
            const geminiApiRoleName = (message.role === "assistant") ? "model" : message.role;
            const usingSearch = tools[0]?.google_search !== undefined
            // functionResponse first: output messages now also carry a
            // functionCall stub (the originating call id)
            if (!usingSearch && (message.functionResponse?.length > 0) && message.functionName.length > 0) {
                return {
                    "role": geminiApiRoleName,
                    "parts": [{
                        functionResponse: {
                            "name": message.functionName,
                            "response": { "content": message.functionResponse }
                        }
                    }]
                }
            }
            if (!usingSearch && message.functionCall != undefined && message.functionName.length > 0) {
                return {
                    "role": geminiApiRoleName,
                    "parts": [{
                        functionCall: {
                            "name": message.functionName,
                            "args": (typeof message.functionCall === "object" ? (message.functionCall.args ?? {}) : {}),
                        }
                    }]
                }
            }
            return {
                "role": geminiApiRoleName,
                "parts": [
                    { text: message.rawContent },
                    ...(message.fileUri && message.fileUri.length > 0 ? [{ 
                        "file_data": {
                            "mime_type": message.fileMimeType,
                            "file_uri": message.fileUri
                        }
                    }] : [])
                ]
            }
        })
        if (filePath && filePath.length > 0) {
            const trimmedFilePath = CF.FileUtils.trimFileProtocol(filePath);
            // Add file_data part to the last message's parts array
            contents[contents.length - 1].parts.unshift({
                file_data: {
                    mime_type: fileMimeTypeSubstitutionString,
                    file_uri: fileUriSubstitutionString
                }
            });
        }
        const generationConfig = { "temperature": temperature };
        // Thought summaries only exist on 2.5+ models; older ones reject
        // the field. QML JS does not support object spread in literals.
        if (/gemini-(2\.5|3)/.test(model.model))
            generationConfig.thinkingConfig = { "includeThoughts": true };

        let baseData = {
            "contents": contents,
            "tools": tools,
            "system_instruction": {
                "parts": [{ text: systemPrompt }]
            },
            "generationConfig": generationConfig,
        };
        // print("Gemini API call payload:", JSON.stringify(baseData, null, 2));
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        // Gemini doesn't use Authorization header, key is in URL
        return "";
    }

    function parseResponseLine(line, message) {
        if (line.startsWith("[")) {
            buffer += line.slice(1).trim();
        } else if (line === "]") {
            buffer += line.slice(0, -1).trim();
            return parseBuffer(message);
        } else if (line.startsWith(",")) {
            return parseBuffer(message);
        } else {
            buffer += line.trim();
        }
        return {};
    }

    function parseBuffer(message) {
        // console.log("[Ai] Gemini buffer: ", buffer);
        let finished = false;
        try {
            if (buffer.length === 0) return {};
            const dataJson = JSON.parse(buffer);

            // Uploaded file
            if (dataJson.uploadedFile) {
                message.fileUri = dataJson.uploadedFile.uri;
                message.fileMimeType = dataJson.uploadedFile.mimeType;
                return ({})
            }

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error ${dataJson.error.code}**: ${dataJson.error.message}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            // No candidates?
            if (!dataJson.candidates) return {};
            
            // Finished?
            if (dataJson.candidates[0]?.finishReason) {
                finished = true;
            }
            
            // Walk every part: text, thought summaries, and function calls
            // can share a chunk (reading only parts[0] dropped content)
            const parts = dataJson.candidates[0]?.content?.parts ?? [];
            let functionCallResult = null;
            for (const part of parts) {
                if (part.functionCall) {
                    const functionCall = part.functionCall;
                    message.functionName = functionCall.name;
                    const newContent = `\n\n[[ Function: ${functionCall.name}(${JSON.stringify(functionCall.args, null, 2)}) ]]\n`
                    message.rawContent += newContent;
                    message.content += newContent;
                    functionCallResult = { name: functionCall.name, args: functionCall.args };
                    continue;
                }
                if (part.text === undefined || part.text === null) continue;
                if (part.thought === true) {
                    if (!isThinking) {
                        isThinking = true;
                        message.rawContent += "\n\n<think>\n\n";
                        message.content += "\n\n<think>\n\n";
                    }
                } else if (isThinking) {
                    isThinking = false;
                    message.rawContent += "\n\n</think>\n\n";
                    message.content += "\n\n</think>\n\n";
                }
                message.rawContent += part.text;
                message.content += part.text;
            }
            if (functionCallResult) {
                return { functionCall: functionCallResult, finished: finished };
            }
            
            // Handle annotations and metadata
            const annotationSources = dataJson.candidates[0]?.groundingMetadata?.groundingChunks?.map(chunk => {
                return {
                    "type": "url_citation",
                    "text": chunk?.web?.title,
                    "url": chunk?.web?.uri,
                }
            }) ?? [];

            const annotations = dataJson.candidates[0]?.groundingMetadata?.groundingSupports?.map(citation => {
                return {
                    "type": "url_citation",
                    "start_index": citation.segment?.startIndex,
                    "end_index": citation.segment?.endIndex,
                    "text": citation?.segment.text,
                    "url": annotationSources[citation.groundingChunkIndices[0]]?.url,
                    "sources": citation.groundingChunkIndices
                }
            });
            message.annotationSources = annotationSources;
            message.annotations = annotations;
            message.searchQueries = dataJson.candidates[0]?.groundingMetadata?.webSearchQueries ?? [];

            // Usage metadata
            if (dataJson.usageMetadata) {
                return {
                    tokenUsage: {
                        input: dataJson.usageMetadata.promptTokenCount ?? -1,
                        output: dataJson.usageMetadata.candidatesTokenCount ?? -1,
                        total: dataJson.usageMetadata.totalTokenCount ?? -1
                    },
                    finished: finished
                };
            }
            
        } catch (e) {
            console.log("[AI] Gemini: Could not parse buffer: ", e);
            message.rawContent += buffer;
            message.content += buffer;
        } finally {
            buffer = "";
        }
        return { finished: finished };
    }

    function onRequestFinished(message) {
        return parseBuffer(message);
    }
    
    function reset() {
        buffer = "";
        isThinking = false;
    }

    function buildScriptFileSetup(filePath) {
        const trimmedFilePath = CF.FileUtils.trimFileProtocol(filePath);
        let content = ""

        // print("file path:", filePath)
        // print("trimmed file path:", trimmedFilePath)
        // print("escaped file path:", CF.StringUtils.shellSingleQuoteEscape(trimmedFilePath))

        content += `IMAGE_PATH='${CF.StringUtils.shellSingleQuoteEscape(trimmedFilePath)}'\n`;
        content += `${fileMimeTypeVarName}=$(file -b --mime-type "$IMAGE_PATH")\n`;
        content += 'NUM_BYTES=$(wc -c < "${IMAGE_PATH}")\n';
        content += 'tmp_header_file="/tmp/quickshell/ai/upload-header.tmp"\n';
        content += 'tmp_file_info_file="/tmp/quickshell/ai/file-info.json.tmp"\n';

        // Initial resumable request defining metadata.
        // The upload url is in the response headers dump them to a file.
        content += 'curl "https://generativelanguage.googleapis.com/upload/v1beta/files"'
            + ` -H "x-goog-api-key: \$${apiKeyEnvVarName}"`
            + ' -D $tmp_header_file'
            + ' -H "X-Goog-Upload-Protocol: resumable"'
            + ' -H "X-Goog-Upload-Command: start"'
            + ' -H "X-Goog-Upload-Header-Content-Length: ${NUM_BYTES}"'
            + ` -H "X-Goog-Upload-Header-Content-Type: \${${fileMimeTypeVarName}}"`
            + ' -H "Content-Type: application/json"'
            + ` -d "{'file': {'display_name': 'Image'}}" 2> /dev/null`
            + '\n';

        // Get file upload header
        content += 'upload_url=$(grep -i "x-goog-upload-url: " "${tmp_header_file}" | cut -d" " -f2 | tr -d "\r")\n';
        content += 'rm "${tmp_header_file}"\n';

        // Upload the actual file
        content += 'curl "${upload_url}"'
            + ` -H "x-goog-api-key: \$${apiKeyEnvVarName}"`
            + ' -H "Content-Length: ${NUM_BYTES}"'
            + ' -H "X-Goog-Upload-Offset: 0"'
            + ' -H "X-Goog-Upload-Command: upload, finalize"'
            + ' --data-binary "@${IMAGE_PATH}" 2> /dev/null > "${tmp_file_info_file}"'
            + '\n';

        content += `${fileUriVarName}=$(jq -r ".file.uri" "$tmp_file_info_file")\n`
        content += `printf "{\\"uploadedFile\\": {\\"uri\\": \\"$${fileUriVarName}\\", \\"mimeType\\": \\"$${fileMimeTypeVarName}\\"}}\\n,\\n"\n`

        return content
    }

    function finalizeScriptContent(scriptContent: string): string {
        return scriptContent.replace(fileMimeTypeSubstitutionString, `'"\$${fileMimeTypeVarName}"'`)
                            .replace(fileUriSubstitutionString, `'"\$${fileUriVarName}"'`);
    }
}
