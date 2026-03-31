# Local Development Testing with Mononoke

This guide covers running a local Mononoke instance for testing server-side
features. It uses the `mononoke-bootstrap` scripts and optionally sets up
tmux for a convenient multi-pane workflow.

## Prerequisites

- A devserver (OnDemand may not work)
- Buck2 for building binaries
- tmux (optional, for the multi-pane setup)

## Quick Start

### 1. Bootstrap

Pick a directory for your local Mononoke data. This guide uses `~/local/mymononoke`:

```bash
./eden/mononoke/facebook/mononoke-bootstrap/bootstrap.sh ~/local/mymononoke
```

### 2. Build Binaries

Build all bootstrap binaries in opt mode (dev mode is too slow):

```bash
buck2 build @mode/opt //eden/mononoke/facebook/mononoke-bootstrap:binaries --num-threads 4
```

`--num-threads 4` avoids OOM during linking. Skip it on jumbo devservers.

### 3. Configure

The repo config lives at `~/local/mymononoke/config/repos/mymononoke/server.toml`.
Edit it to enable features you want to test (e.g. additional derived data types,
hooks, pushrebase settings).

### 4. Start the Servers

```bash
cd ~/local/mymononoke
./bin/mononoke.sh
```

The Mononoke server runs in the foreground. In a separate terminal (or tmux
pane), start the SCS server for Thrift access:

```bash
cd ~/local/mymononoke
./bin/scs-server.sh
```

You can verify SCS is running with:

```bash
scsc -H localhost:8367 repos
```

See the [Tmux Setup](#tmux-setup) section below for a convenient multi-pane
layout.

### 5. Clone and Create Test Commits

```bash
./bin/hg-clone.sh
cd hg

# First commit needs --create
echo "base" > base.txt
hg add base.txt
hg commit -m "Base commit"
hg push --to main --force --create

# Subsequent commits
echo "hello" > hello.txt
hg add hello.txt
hg commit -m "Add hello.txt"
hg push --to main --force
```

### 6. Creating Merge Commits

Client-side merges are disabled by default. Enable them with
`--config ui.allowmerge=True`:

```bash
# Create branch A
echo "a" > branch_a.txt
hg add branch_a.txt
hg commit -m "Branch A"

# Create branch B from main
hg checkout remote/main
echo "b" > branch_b.txt
hg add branch_b.txt
hg commit -m "Branch B"

# Merge
hg merge -r <branch-a-hash> --config ui.allowmerge=True
hg commit -m "Merge A and B"
hg push --to main --force
```

### 7. Admin CLI

The admin CLI can be used for inspecting and operating on the local repo:

```bash
cd ~/local/mymononoke

# Example: derive data for the main bookmark
./bin/admin.sh derived-data -R mymononoke derive -B main -T <type>

# Example: check if derived data exists
./bin/admin.sh derived-data -R mymononoke exists -B main -T <type>

# Example: list manifest contents
./bin/admin.sh derived-data -R mymononoke list-manifest -B main \
  --manifest-type <manifest-type> -r
```

The `-i <hash>` flag accepts full 40-character hg hashes as an alternative
to `-B <bookmark>`.

### 8. Starting Fresh

To wipe everything and start over:

```bash
# Stop the servers (Ctrl-C in their terminals)
rm -rf ~/local/mymononoke
./eden/mononoke/facebook/mononoke-bootstrap/bootstrap.sh ~/local/mymononoke
# Re-apply config changes, restart servers, re-clone
```

## Tmux Setup

A tmux-based workflow lets you run servers, the hg client, and admin CLI
side by side. There are two approaches:

### Option A: Separate Windows

Each service gets its own full-screen window. Switch between them with
`Ctrl-b <number>` or `Ctrl-b n`/`Ctrl-b p`.

```bash
tmux new-window -a -n "mononoke-srv" -c "$HOME/local/mymononoke"
tmux new-window -a -n "scs-srv"      -c "$HOME/local/mymononoke"
tmux new-window -a -n "admin"        -c "$HOME/local/mymononoke"
tmux new-window -a -n "hg-client"    -c "$HOME/local/mymononoke/hg"
```

### Option B: Panes in a Single Window

Everything visible at once in a split layout. Useful for watching server logs
while running commands.

```bash
# Create a new window for the workspace
tmux new-window -a -n "mononoke-dev" -c "$HOME/local/mymononoke"

# Split into a 2x2 grid
tmux split-window -h -c "$HOME/local/mymononoke"       # right pane
tmux split-window -v -c "$HOME/local/mymononoke/hg"    # bottom-right
tmux select-pane -t 0
tmux split-window -v -c "$HOME/local/mymononoke"       # bottom-left

# Result:
# ┌──────────────────┬──────────────────┐
# │ mononoke server  │ scs server       │
# ├──────────────────┼──────────────────┤
# │ admin CLI        │ hg client        │
# └──────────────────┴──────────────────┘

# Navigate between panes with Ctrl-b <arrow key>
```

### Start the Servers

In the Mononoke server pane/window:

```bash
export MONONOKE_HOME=$HOME/local/mymononoke
cd $MONONOKE_HOME
./bin/mononoke.sh
```

In the SCS server pane/window:

```bash
export MONONOKE_HOME=$HOME/local/mymononoke
cd $MONONOKE_HOME
./bin/scs-server.sh
```

### Use the Other Panes/Windows

- **hg-client**: create commits, push, view smartlog (`hg sl`)
- **admin**: inspect repo state, derive data, run admin commands

## Troubleshooting

### `env.txt: No such file or directory`

You need to build the bootstrap binaries target:

```bash
buck2 build @mode/opt //eden/mononoke/facebook/mononoke-bootstrap:binaries --num-threads 4
```

### `Invalid commit id` from admin CLI

The `-i` flag requires full 40-character hg hashes. Get them with:

```bash
hg log -r 'all()' -T '{node} {desc|firstline}\n'
```

### `abort: could not find remote bookmark 'main'`

Use `--create` on the first push:

```bash
hg push --to main --force --create
```

### Permission errors with `scsc`

Edit `~/local/mymononoke/config/common/common.toml` and set
`[internal_identity]` to match `[[global_allowlist]]`. See the
[Running Locally wiki](https://www.internalfb.com/wiki/Source_Control/Mononoke/Development/Running_Locally_for_Development)
for details.

### Stale data after code changes

The local blobstore caches data. To start clean after changing server code,
wipe the mononoke home directory and re-bootstrap (see "Starting Fresh" above).
