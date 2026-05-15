FROM node:24-bookworm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    ncurses-term \
    ripgrep \
    fd-find \
    zip \
    unzip \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    @anthropic-ai/claude-code@latest \
    opencode-ai@latest \
    @earendil-works/pi-coding-agent@latest \
    @openai/codex@latest

WORKDIR /workspace

CMD ["bash"]
