FROM node:26-bookworm

# --------------------------------------------------------------------------------------
# System packages
# --------------------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # Claude Code sandboxing
        bubblewrap   \
        socat        \
        # Terminal support
        ncurses-term \
        # Common utilities
        curl         \
        fd-find      \
        git          \
        jq           \
        ripgrep      \
        # Python environment
        python3      \
        python3-pip  \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------------------
# Coding agents
# --------------------------------------------------------------------------------------

RUN npm install -g \
    @anthropic-ai/claude-code@latest \
    @earendil-works/pi-coding-agent@latest \
    @openai/codex@latest \
    opencode-ai@latest

# --------------------------------------------------------------------------------------
# Shell prompt
# --------------------------------------------------------------------------------------

RUN printf '\nPS1='\''(${AGENT_PROJECT_NAME:-sandbox}) \w\$ '\''\n' \
    >> /etc/bash.bashrc

# --------------------------------------------------------------------------------------
# Workspace
# --------------------------------------------------------------------------------------

WORKDIR /workspace

CMD ["bash"]
