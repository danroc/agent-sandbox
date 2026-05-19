FROM node:26-bookworm

# --------------------------------------------------------------------------------------
# GitHub CLI repository
# --------------------------------------------------------------------------------------

RUN curl -fsSL \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /etc/apt/keyrings/githubcli-archive-keyring.gpg

RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list

# --------------------------------------------------------------------------------------
# System packages
# --------------------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # Claude Code sandboxing
        bubblewrap   \
        socat        \
        \
        # Terminal support
        ncurses-term \
        \
        # Common utilities
        curl         \
        fd-find      \
        gh           \
        git          \
        jq           \
        ripgrep      \
        \
        # Python
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
