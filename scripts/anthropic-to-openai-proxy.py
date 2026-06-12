#!/usr/bin/env python3
"""
API 翻译代理：将 Claude Code 的 Anthropic 格式请求转换为 DeepSeek 的 OpenAI 格式
运行在服务器上，监听 localhost:3456
"""
import http.server
import json
import urllib.request
import ssl
import sys
import os

LISTEN_PORT = int(os.environ.get("PROXY_PORT", "3456"))
DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"
DEEPSEEK_KEY = os.environ.get("DEEPSEEK_API_KEY", "")

# 允许自签名证书（如果走代理可能需要）
ssl_ctx = ssl.create_default_context()

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        
        try:
            req = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        # 从 Anthropic x-api-key header 或环境变量获取 API Key
        api_key = self.headers.get("x-api-key", "") or DEEPSEEK_KEY
        if not api_key:
            self.send_error(401, "No API key")
            return

        # ---- 翻译 Anthropic → OpenAI ----
        openai_req = {
            "model": req.get("model", "deepseek-v4-flash"),
            "messages": req.get("messages", []),
            "max_tokens": req.get("max_tokens", 4096),
            "temperature": req.get("temperature", 0.7),
            "stream": req.get("stream", False),
        }

        # 处理 system prompt
        if "system" in req:
            if isinstance(req["system"], str):
                openai_req["messages"].insert(0, {"role": "system", "content": req["system"]})
            elif isinstance(req["system"], list):
                for s in req["system"]:
                    if isinstance(s, dict) and s.get("type") == "text":
                        openai_req["messages"].insert(0, {"role": "system", "content": s["text"]})

        # 处理 stop_sequences
        if "stop_sequences" in req:
            openai_req["stop"] = req["stop_sequences"]

        # ---- 发送到 DeepSeek ----
        try:
            http_req = urllib.request.Request(
                DEEPSEEK_URL,
                data=json.dumps(openai_req).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
            )
            with urllib.request.urlopen(http_req, context=ssl_ctx, timeout=120) as resp:
                ds_body = resp.read()
                ds_resp = json.loads(ds_body)
        except Exception as e:
            self.send_error(502, f"DeepSeek API error: {e}")
            return

        # ---- 翻译 OpenAI 响应 → Anthropic ----
        anthropic_resp = self._translate_response(ds_resp, req)

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(anthropic_resp).encode("utf-8"))

    def _translate_response(self, ds_resp, original_req):
        """将 DeepSeek (OpenAI 格式) 响应翻译为 Anthropic 格式"""
        choice = ds_resp.get("choices", [{}])[0]
        message = choice.get("message", {})

        content = []
        
        # 文本内容
        if message.get("content"):
            content.append({
                "type": "text",
                "text": message["content"]
            })
        
        # 推理内容 (DeepSeek R1/V4 的 reasoning)
        if message.get("reasoning_content"):
            content.insert(0, {
                "type": "thinking",
                "thinking": message["reasoning_content"]
            })

        if not content:
            content = [{"type": "text", "text": ""}]

        usage = ds_resp.get("usage", {})
        
        return {
            "id": f"msg_{ds_resp.get('id', 'unknown')}",
            "type": "message",
            "role": "assistant",
            "model": ds_resp.get("model", original_req.get("model", "")),
            "content": content,
            "stop_reason": choice.get("finish_reason", "end_turn"),
            "stop_sequence": None,
            "usage": {
                "input_tokens": usage.get("prompt_tokens", 0),
                "output_tokens": usage.get("completion_tokens", 0),
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
            },
        }

    def do_GET(self):
        """处理 GET 请求（模型列表等）"""
        if "/v1/models" in self.path:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            resp = {
                "data": [
                    {"id": "deepseek-v4-pro", "object": "model", "created": 1},
                    {"id": "deepseek-v4-flash", "object": "model", "created": 1},
                ]
            }
            self.wfile.write(json.dumps(resp).encode("utf-8"))
        else:
            self.send_error(404, "Not found")

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}", file=sys.stderr)


if __name__ == "__main__":
    print(f"🔄 Anthropic→OpenAI 翻译代理启动")
    print(f"   监听: localhost:{LISTEN_PORT}")
    print(f"   转发: {DEEPSEEK_URL}")
    server = http.server.HTTPServer(("127.0.0.1", LISTEN_PORT), ProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n代理已停止")
        server.shutdown()
