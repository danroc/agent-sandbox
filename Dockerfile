FROM node:24-bookworm

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    ripgrep \
    fd-find \
    unzip \
    zip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    @anthropic-ai/claude-code@latest \
    opencode-ai@latest \
    @earendil/pi@latest \
    @openai/codex@latest

WORKDIR /workspace

CMD ["bash"]
