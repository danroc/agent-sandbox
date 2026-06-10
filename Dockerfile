FROM node:26-bookworm

ARG APT_PACKAGES=""
ARG NPM_PACKAGES=""

# --------------------------------------------------------------------------------------
# System packages
# --------------------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # Claude Code sandboxing
        bubblewrap \
        socat \
        # Terminal support
        ncurses-term \
        # Common utilities
        curl \
        fd-find \
        git \
        jq \
        ripgrep \
        # Python environment
        python3 \
        python3-pip \
        python3-venv \
        # Additional packages
        $APT_PACKAGES \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------------------
# Coding agents
# --------------------------------------------------------------------------------------

RUN npm install -g \
    # Agents
    @anthropic-ai/claude-code@latest \
    @earendil-works/pi-coding-agent@latest \
    @github/copilot@latest \
    @openai/codex@latest \
    opencode-ai@latest \
    # Additional packages
    $NPM_PACKAGES

ENV CURSOR_AGENT_HOME=/opt/cursor-agent
RUN mkdir -p "$CURSOR_AGENT_HOME" \
    && export HOME="$CURSOR_AGENT_HOME" \
    && curl -fsS https://cursor.com/install | bash \
    && ln -sf "$CURSOR_AGENT_HOME/.local/bin/cursor-agent" /usr/local/bin/cursor

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
