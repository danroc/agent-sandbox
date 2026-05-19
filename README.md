# agent-sandbox

Run AI coding CLIs (Claude Code, OpenCode, Pi, Codex) inside a sandboxed Docker
container with an isolated `$HOME`. The current directory is mounted as `/workspace`;
the sandbox home lives at `~/.agent-sandbox/home`.

## Installation

```sh
# 1. Clone into ~/.agent-sandbox so the home mount lives alongside the repo
git clone git@github.com:danroc/agent-sandbox.git ~/.agent-sandbox

# 2. Symlink the launcher onto your PATH
ln -s ~/.agent-sandbox/agent ~/.local/bin/agent

# 3. Build the image
agent update

# 4. Set git identity inside the sandbox home (persists across runs)
agent bash git config --global user.name  "Your Name"
agent bash git config --global user.email "you@example.com"
```

## Usage

```sh
agent                  # Interactive bash shell
agent claude           # Start Claude Code
agent opencode         # Start opencode
agent pi               # Start pi
agent codex            # Start codex
agent versions         # Print tool versions
agent update           # Rebuild the image
```

Arguments after the command are forwarded, e.g. `agent claude -p "explain repo"`.

The launcher accepts flags before the command name:

```sh
agent -p 5173 bash                 # Publish port 5173 to the container
agent -e NODE_ENV=development bash # Set an environment variable
agent -e DEBUG codex               # Pass a host env var through
agent -v "$PWD/scratch:/scratch" bash  # Mount an extra directory
```

## Reaching host services

From inside the sandbox, `localhost` is the container itself. To reach a service
running on the host, use `host.docker.internal`. The service must be bound to a
non-loopback address (e.g. `0.0.0.0`) for the container to reach it.

## Customizing the sandbox

`agent` reads an optional config file at `~/.agent-sandbox/config.sh`. Copy the
included example to get started:

```sh
cp ~/.agent-sandbox/config.sh.example ~/.agent-sandbox/config.sh
```

The config exposes three arrays:

- `APT_PACKAGES` — extra Debian packages baked into the image.
- `NPM_PACKAGES` — extra global npm packages baked into the image.
- `MOUNTS` — extra volume mounts applied to every run, in `-v SOURCE:TARGET[:ro]`
  syntax. Shell expansions like `$HOME` are supported.

Run `agent update` after changing `APT_PACKAGES` or `NPM_PACKAGES` to rebuild
the image. `MOUNTS` changes take effect on the next run with no rebuild needed.
