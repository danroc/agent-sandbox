FROM node:26-bookworm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Sandboxing
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
    unzip \
    zip \
    # Python and related tools
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    @anthropic-ai/claude-code@latest \
    @earendil-works/pi-coding-agent@latest \
    @openai/codex@latest \
    opencode-ai@latest

WORKDIR /workspace

CMD ["bash"]
