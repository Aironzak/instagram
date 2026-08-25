#!/usr/bin/env python3
"""Connect the Higgsfield MCP server to Claude Code, and print a sign-in link.

Why this exists: `claude mcp login higgsfield` always fails with

    Issuer mismatch in authorization response (RFC 9207):
    expected "https://mcp.higgsfield.ai", received "https://clerk.higgsfield.ai"

Higgsfield's own metadata declares `issuer: https://mcp.higgsfield.ai`, but the
redirect back to the callback carries the upstream Clerk issuer instead. Claude
Code rejects that correctly and there is no flag to disable the check. Their
advertised device-code server (fnf-device-auth.higgsfield.ai) returns 404 on every
endpoint, so that route is not available either.

This script runs the same authorization-code + PKCE flow with the same PKCE
challenge and the same `state` check, and skips only the `iss` comparison — a
mix-up protection that matters when a client talks to several authorization
servers. Here the server is fixed, taken from Higgsfield's own metadata, and
there is exactly one. The token is then written into the user-scope MCP config
as a static `Authorization: Bearer` header.

    python3 connect_higgsfield.py            sign in and configure
    python3 connect_higgsfield.py --refresh  renew an expired access token
    python3 connect_higgsfield.py --status   report what is configured
"""

import base64
import hashlib
import http.server
import json
import os
import secrets
import socketserver
import subprocess
import sys
import threading
import urllib.parse
import urllib.request

AS = "https://mcp.higgsfield.ai"
RESOURCE = "https://mcp.higgsfield.ai/mcp"
SERVER_NAME = "higgsfield"
PORT = 7391
REDIRECT = f"http://localhost:{PORT}/callback"
STORE = os.path.expanduser("~/.roomwalk/higgsfield_tokens.json")
WAIT_SECONDS = 1800


def post_json(url, payload):
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(), method="POST",
        headers={"Content-Type": "application/json", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def post_form(url, payload):
    req = urllib.request.Request(
        url, data=urllib.parse.urlencode(payload).encode(), method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded",
                 "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def save(tok):
    os.makedirs(os.path.dirname(STORE), exist_ok=True)
    with open(STORE, "w") as f:
        json.dump(tok, f, indent=2)
    os.chmod(STORE, 0o600)


def configure(access_token):
    """Point the user-scope MCP config at Higgsfield with a static bearer header."""
    subprocess.run(["claude", "mcp", "remove", SERVER_NAME, "-s", "user"],
                   capture_output=True, check=False)
    r = subprocess.run(
        ["claude", "mcp", "add", "--transport", "http", SERVER_NAME, RESOURCE,
         "--header", f"Authorization: Bearer {access_token}", "--scope", "user"],
        capture_output=True, text=True, check=False)
    if r.returncode != 0:
        sys.exit(f"could not configure the MCP server: {r.stderr.strip()}")
    print(f"MCP server '{SERVER_NAME}' configured (user scope).")


def status():
    if not os.path.exists(STORE):
        print("Not connected — no stored token.")
    else:
        tok = json.load(open(STORE))
        print(f"Token stored at {STORE}"
              f" (refresh token: {'yes' if tok.get('refresh_token') else 'no'}).")
    r = subprocess.run(["claude", "mcp", "get", SERVER_NAME],
                       capture_output=True, text=True, check=False)
    print(r.stdout.strip() or "MCP server not configured.")


def refresh():
    if not os.path.exists(STORE):
        sys.exit("nothing to refresh — run without --refresh first")
    tok = json.load(open(STORE))
    if not tok.get("refresh_token"):
        sys.exit("the stored token has no refresh_token — sign in again")
    new = post_form(f"{AS}/oauth2/token", {
        "grant_type": "refresh_token",
        "refresh_token": tok["refresh_token"],
        "client_id": tok["_client_id"],
        "resource": RESOURCE,
    })
    new.setdefault("refresh_token", tok["refresh_token"])
    new["_client_id"] = tok["_client_id"]
    save(new)
    configure(new["access_token"])
    print("Access token renewed.")


def login():
    reg = post_json(f"{AS}/oauth2/register", {
        "client_name": "roomwalk",
        "redirect_uris": [REDIRECT],
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "token_endpoint_auth_method": "none",
        "scope": "openid email offline_access",
    })
    client_id = reg["client_id"]

    verifier = base64.urlsafe_b64encode(secrets.token_bytes(64)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(32)

    auth_url = f"{AS}/oauth2/authorize?" + urllib.parse.urlencode({
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": REDIRECT,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "state": state,
        "scope": "openid email offline_access",
        "prompt": "consent",
        "resource": RESOURCE,
    })

    result, done = {}, threading.Event()

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _finish(self, code, body):
            self.send_response(code)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body.encode())

        def do_GET(self):
            parts = urllib.parse.urlparse(self.path)
            if parts.path != "/callback":
                self._finish(404, "not found")
                return
            q = urllib.parse.parse_qs(parts.query)
            if q.get("state", [None])[0] != state:
                result["error"] = "state mismatch"
                self._finish(400, "<h2>State mismatch — sign-in refused.</h2>")
            elif "error" in q:
                result["error"] = q["error"][0]
                self._finish(400, f"<h2>{q['error'][0]}</h2>")
            else:
                result["code"] = q["code"][0]
                self._finish(200, "<h2>Higgsfield connected. You can close this tab.</h2>")
            done.set()

        def do_POST(self):
            n = int(self.headers.get("Content-Length", 0))
            q = urllib.parse.parse_qs(self.rfile.read(n).decode())
            self.path = "/callback?" + urllib.parse.urlencode({k: v[0] for k, v in q.items()})
            self.do_GET()

    socketserver.TCPServer.allow_reuse_address = True
    srv = socketserver.TCPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    print()
    print("Open this link and sign in to your Higgsfield account:")
    print()
    print(f"  {auth_url}")
    print()
    print(f"Waiting for you to finish (up to {WAIT_SECONDS // 60} minutes)…")
    # Открыть браузер сами, если получится. Раньше здесь был macOS-only `open`,
    # из-за чего на Windows и Linux ссылку приходилось нести руками. Ссылка
    # печатается выше в любом случае, так что неудача здесь ничего не ломает.
    try:
        import webbrowser
        webbrowser.open(auth_url)
    except Exception:
        pass

    if not done.wait(timeout=WAIT_SECONDS):
        srv.shutdown()
        sys.exit("timed out — nobody completed the sign-in")
    srv.shutdown()
    if "error" in result:
        sys.exit(f"sign-in failed: {result['error']}")

    tok = post_form(f"{AS}/oauth2/token", {
        "grant_type": "authorization_code",
        "code": result["code"],
        "redirect_uri": REDIRECT,
        "client_id": client_id,
        "code_verifier": verifier,
    })
    tok["_client_id"] = client_id
    save(tok)
    configure(tok["access_token"])
    print()
    print("Done. Restart Claude Code so the Higgsfield tools load.")


if __name__ == "__main__":
    if "--status" in sys.argv:
        status()
    elif "--refresh" in sys.argv:
        refresh()
    else:
        login()
