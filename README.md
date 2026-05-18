# agent-sandbox

Run AI coding CLIs (Claude Code, OpenCode, Pi, Codex) inside a sandboxed Docker
container with an isolated `$HOME`. The current directory is mounted as `/workspace`;
the sandbox home lives at `~/.agent-sandbox/home`.

## Bootstrap

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

Launcher options before the command are passed to Docker:

```sh
agent -p 5173 bash                 # Publish host port 5173 to container port 5173
agent -e NODE_ENV=development bash # Set an environment variable
agent -e DEBUG codex               # Pass a host environment variable through
```

## Reaching host services

From inside the sandbox, `localhost` is the container itself. To reach a server running
on the host, use `host.docker.internal`. The host service must also be bound to a
non-loopback address (e.g. `0.0.0.0`) for the container to connect.

## Customizing the sandbox

`agent` reads an optional bash config file at `~/.agent-sandbox/config.sh`. Copy
the included `config.sh.example` to get started:

```sh
cp ~/.agent-sandbox/config.sh.example ~/.agent-sandbox/config.sh
```

The config exposes three arrays:

- `APT_PACKAGES` — extra Debian packages baked into the image.
- `NPM_PACKAGES` — extra global npm packages baked into the image.
- `MOUNTS` — extra volume mounts applied to every container run, in docker
  `-v` syntax (`SOURCE:TARGET[:ro]`). `$HOME` and other shell expansions work.

Run `agent update` after changing `APT_PACKAGES` or `NPM_PACKAGES` to rebuild
the image. `MOUNTS` changes apply on the next `agent` run with no rebuild.

The `-v/--volume` launcher flag adds one-shot mounts on top of the config:

```sh
agent -v "$PWD/scratch:/scratch" bash
```
