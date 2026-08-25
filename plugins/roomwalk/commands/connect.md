---
description: Connect the Higgsfield MCP server — prints a sign-in link, then configures Claude Code
---

Run the connector script that ships with the roomwalk skill:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/roomwalk/tools/connect_higgsfield.py"
```

Run it in the background, then read its output and give the user the sign-in
link it prints. The script waits up to thirty minutes for them to finish, then
writes the token into the user-scope MCP config by itself.

Tell the user two things and nothing more:

1. The link, on its own line, so it is easy to click.
2. That Claude Code needs a restart afterwards for the Higgsfield tools to load.

If the script reports it is already connected, say so and skip the link. If the
token has expired, run it again with `--refresh` instead of a fresh sign-in.
