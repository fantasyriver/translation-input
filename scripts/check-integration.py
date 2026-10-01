#!/usr/bin/env python3
"""Ephemeral HTTP fixtures, not a product server. No external API calls or keys."""
import collections
import http.server
import json
import os
import pathlib
import secrets
import subprocess
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
KEY = secrets.token_urlsafe(24)
seen = collections.Counter()
errors = []


def chat(text="Hello 🌏\nSee you tomorrow", reason="stop"):
    return {"choices": [{"message": {"role": "assistant", "content": text}, "finish_reason": reason}]}


class Fixture(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        seen[self.path] += 1
        try:
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            assert body["messages"][-1]["content"] == "你好 🌏\n明天见"
            assert body["stream"] is False
            assert self.headers["Content-Type"] == "application/json"
            if self.path == "/claude":
                assert self.headers["x-api-key"] == KEY
                assert self.headers["anthropic-version"] == "2023-06-01"
                assert self.headers.get("Authorization") is None
                assert len(body["messages"]) == 1 and "English" in body["system"]
            else:
                assert body["messages"][0]["role"] == "system"
                assert self.headers.get("x-api-key") is None
                assert self.headers.get("Authorization") == (None if self.path == "/no-key" else "Bearer " + KEY)
            models = {"/openai": "gpt-5-nano", "/claude": "claude-haiku-4-5-20251001", "/deepseek": "deepseek-flash", "/glm": "glm-4.7-flash", "/minimax": "MiniMax-M3", "/qwen": "qwen-turbo"}
            if self.path in models:
                assert body["model"] == models[self.path]
            if self.path in ["/deepseek", "/glm", "/minimax"]:
                assert body["thinking"] == {"type": "disabled"}
            if self.path == "/openai":
                assert body["reasoning_effort"] == "minimal" and body["max_completion_tokens"] == 8192
                assert "max_tokens" not in body
            if self.path == "/qwen":
                assert body["enable_thinking"] is False
            if self.path == "/minimax":
                assert body["reasoning_split"] is True
            if self.path.startswith("/status/"):
                status = int(self.path.split("/")[-1])
                self.send_response(status)
                if status == 307:
                    self.send_header("Location", f"http://127.0.0.1:{self.server.server_port}/redirect-target")
                self.end_headers()
                return
            response = chat()
            if self.path == "/claude":
                response = {"type": "message", "role": "assistant", "stop_reason": "end_turn", "content": [{"type": "text", "text": "Hello 🌏\nSee you tomorrow"}]}
            if self.path == "/truncated":
                response = chat("partial", "length")
            if self.path == "/empty":
                response = chat(" ")
            if self.path == "/refused":
                response["choices"][0]["message"]["refusal"] = "fixture refusal"
            if self.path == "/slow-headers":
                time.sleep(3)
            data = json.dumps(response, ensure_ascii=False).encode()
            if self.path == "/malformed":
                data = b'not json'
            if self.path.startswith("/oversized"):
                data = b'a' * (512 * 1024 + 1)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            if self.path != "/oversized-chunked":
                self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            if self.path == "/slow-body":
                self.wfile.write(data[:1]); self.wfile.flush(); time.sleep(3)
                data = data[1:]
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Expected when the client rejects or cancels a response.
        except Exception as error:
            errors.append(type(error).__name__ + " at " + self.path)
            self.send_error(500)


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    env = dict(os.environ, CHECK_ENDPOINT=f"http://127.0.0.1:{server.server_port}", CHECK_TOKEN=KEY)
    subprocess.run(["swift", "run", "--package-path", str(ROOT / "macos"), "CoreChecks", "--integration"], env=env, check=True, timeout=30)
    assert not errors, errors
    assert "/redirect-target" not in seen, "Credentials followed a redirect"
    assert all(count == 1 for count in seen.values()), "Unexpected automatic retry"
    assert len(seen) == 22, ("Missing scenarios", list(seen))
    print("PASS: 22 HTTP scenarios, no redirects or automatic retries")
finally:
    server.shutdown(); server.server_close(); thread.join(timeout=2)
