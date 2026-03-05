#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_BREW=false

for arg in "$@"; do
    case "$arg" in
        --skip-brew) SKIP_BREW=true ;;
    esac
done

if [ "$SKIP_BREW" = false ]; then
    # Ask for sudo password upfront and keep session alive
    echo "You will be prompted for your macOS password for Homebrew setup."
    password_casks=$(grep '# Password prompt:' "$DOTFILES_DIR/Brewfile" | sed 's/.*cask "\([^"]*\)".*/\1/')
    if [ -n "$password_casks" ]; then
        echo "These casks will also prompt for your password during installation:"
        echo "$password_casks" | while read -r c; do echo "  - $c"; done
    fi
    sudo -v
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    # Install Homebrew if not present
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Install all packages, apps, and App Store apps (no upgrades)
    echo "Installing packages from Brewfile..."
    HOMEBREW_BUNDLE_FILE="$DOTFILES_DIR/Brewfile" brew bundle --no-upgrade || echo "Some packages failed to install (see above). Continuing..."
fi

# Symlink dotfiles
files=(
    .alias
    .vimrc
    .gitconfig
    .zshrc
    .gitignore_global
    .tmux.conf
    .config/starship.toml
    .config/ghostty/config
    .config/mise/config.toml
    .config/zed/settings.json
)

echo ""
echo "Symlinking dotfiles to $HOME:"
echo ""
printf "  %s\n" "${files[@]}"
echo ""
read -p "Proceed? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

for f in "${files[@]}"; do
    target="$HOME/$f"
    source="$DOTFILES_DIR/$f"

    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "Backing up $target to $target.bak"
        mv "$target" "$target.bak"
    fi

    ln -s "$source" "$target"
    echo "Linked $f"
done

# ── Git hooks ─────────────────────────────────────────────────
git -C "$DOTFILES_DIR" config core.hooksPath hooks
echo "Configured git hooks from hooks/"

# ── AI agent tool configs ─────────────────────────────────────
echo ""
echo "Installing AI agent tool configs..."

# Generate Gemini/Codex command artifacts from dotclaude/commands
if [ -f "$DOTFILES_DIR/scripts/agent-commands.ts" ]; then
    if command -v bun &>/dev/null; then
        bun "$DOTFILES_DIR/scripts/agent-commands.ts" sync
        bun "$DOTFILES_DIR/scripts/agent-commands.ts" sync-allowlist
    else
        echo "Skipping command and allowlist sync (bun not found)"
    fi
fi

# Shared agent instructions -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.gemini"
for pair in ".claude/CLAUDE.md" ".codex/AGENTS.md" ".gemini/GEMINI.md"; do
    target="$HOME/$pair"
    source="$DOTFILES_DIR/dotagents/AGENTS.md"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "Backing up $target to $target.bak"
        mv "$target" "$target.bak"
    fi
    ln -s "$source" "$target"
    echo "Linked dotagents/AGENTS.md -> ~/$pair"
done

# Claude Code settings
target="$HOME/.claude/settings.json"
source="$DOTFILES_DIR/dotclaude/settings.json"
if [ -L "$target" ]; then
    rm "$target"
elif [ -f "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotclaude/settings.json -> ~/.claude/settings.json"

# Claude Code keybindings
target="$HOME/.claude/keybindings.json"
source="$DOTFILES_DIR/dotclaude/keybindings.json"
if [ -L "$target" ]; then
    rm "$target"
elif [ -f "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotclaude/keybindings.json -> ~/.claude/keybindings.json"

# Claude Code status line script
target="$HOME/.claude/statusline.sh"
source="$DOTFILES_DIR/dotclaude/statusline.sh"
if [ -L "$target" ]; then
    rm "$target"
elif [ -f "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotclaude/statusline.sh -> ~/.claude/statusline.sh"

# Claude Code custom commands (directory symlink)
target="$HOME/.claude/commands"
source="$DOTFILES_DIR/dotclaude/commands"
if [ -L "$target" ]; then
    rm "$target"
elif [ -d "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotclaude/commands/ -> ~/.claude/commands/"

# Gemini custom commands (directory symlink)
target="$HOME/.gemini/commands"
source="$DOTFILES_DIR/dotgemini/commands"
if [ -L "$target" ]; then
    rm "$target"
elif [ -d "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotgemini/commands/ -> ~/.gemini/commands/"

# Gemini settings (merge tools only, keep runtime config)
gemini_src="$DOTFILES_DIR/dotgemini/settings.json"
gemini_dst="$HOME/.gemini/settings.json"
if [ -f "$gemini_src" ]; then
    mkdir -p "$HOME/.gemini"
    if [ -f "$gemini_dst" ] && command -v jq &>/dev/null; then
        gemini_tmp="$(mktemp)"
        if jq -s '.[0] * {tools: (.[1].tools // {})}' "$gemini_dst" "$gemini_src" > "$gemini_tmp"; then
            if [ -f "$gemini_dst" ] && diff -q "$gemini_tmp" "$gemini_dst" >/dev/null 2>&1; then
                echo "Skipped dotgemini/settings.json (unchanged)"
            else
                if [ -f "$gemini_dst" ] && [ ! -L "$gemini_dst" ]; then
                    cp "$gemini_dst" "${gemini_dst}.bak"
                    echo "Backing up $gemini_dst to ${gemini_dst}.bak"
                fi
                cp "$gemini_tmp" "$gemini_dst"
                echo "Merged dotgemini/settings.json tools -> ~/.gemini/settings.json"
            fi
        else
            echo "Skipping Gemini settings merge (invalid JSON)"
        fi
        rm -f "$gemini_tmp"
    else
        if [ -f "$gemini_dst" ] && [ ! -L "$gemini_dst" ]; then
            cp "$gemini_dst" "${gemini_dst}.bak"
            echo "Backing up $gemini_dst to ${gemini_dst}.bak"
        fi
        cp "$gemini_src" "$gemini_dst"
        echo "Copied dotgemini/settings.json -> ~/.gemini/settings.json"
    fi
fi

# Suggest installing enabled Claude Code plugins
plugins=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$DOTFILES_DIR/dotclaude/settings.json" 2>/dev/null)
if [ -n "$plugins" ]; then
    echo ""
    echo "Claude Code plugins to install (run inside Claude Code):"
    echo "$plugins" | while read -r plugin; do
        echo "  /plugin install $plugin"
    done
fi

# Codex config (merge, not symlink; Codex overwrites symlinks)
# https://github.com/openai/codex/issues/11061
codex_src="$DOTFILES_DIR/dotcodex/config.toml"
codex_dst="$HOME/.codex/config.toml"
codex_tmp="$(mktemp)"
cp "$codex_src" "$codex_tmp"
if [ -f "$codex_dst" ]; then
    projects="$(awk '
        BEGIN { p = 0 }
        /^\[projects\./ { p = 1; print; next }
        /^\[/ { p = 0 }
        { if (p) print }
    ' "$codex_dst")"
    if [ -n "$projects" ]; then
        printf '\n%s\n' "$projects" >> "$codex_tmp"
    fi
fi
if [ -f "$codex_dst" ] && diff -q "$codex_tmp" "$codex_dst" >/dev/null 2>&1; then
    echo "Skipped dotcodex/config.toml (unchanged)"
else
    if [ -f "$codex_dst" ] && [ ! -L "$codex_dst" ]; then
        cp "$codex_dst" "${codex_dst}.bak"
        echo "Backing up $codex_dst to ${codex_dst}.bak"
    fi
    cp "$codex_tmp" "$codex_dst"
    echo "Merged dotcodex/config.toml -> ~/.codex/config.toml"
fi
rm -f "$codex_tmp"

# Codex custom command skills namespace
mkdir -p "$HOME/.codex/skills"
target="$HOME/.codex/skills/.dotfiles"
source="$DOTFILES_DIR/dotcodex/skills/.dotfiles"
if [ -L "$target" ]; then
    rm "$target"
elif [ -d "$target" ]; then
    echo "Backing up $target to $target.bak"
    mv "$target" "$target.bak"
fi
ln -s "$source" "$target"
echo "Linked dotcodex/skills/.dotfiles -> ~/.codex/skills/.dotfiles"

# Codex allowlist rules (copy, not symlink)
codex_rules_src="$DOTFILES_DIR/dotcodex/rules/default.rules"
codex_rules_dst="$HOME/.codex/rules/default.rules"
if [ -f "$codex_rules_src" ]; then
    mkdir -p "$HOME/.codex/rules"
    if [ -f "$codex_rules_dst" ] && diff -q "$codex_rules_src" "$codex_rules_dst" >/dev/null 2>&1; then
        echo "Skipped dotcodex/rules/default.rules (unchanged)"
    else
        if [ -f "$codex_rules_dst" ] && [ ! -L "$codex_rules_dst" ]; then
            cp "$codex_rules_dst" "${codex_rules_dst}.bak"
            echo "Backing up $codex_rules_dst to ${codex_rules_dst}.bak"
        fi
        cp "$codex_rules_src" "$codex_rules_dst"
        echo "Copied dotcodex/rules/default.rules -> ~/.codex/rules/default.rules"
    fi
fi

# ── MCP servers ───────────────────────────────────────────────
# Source of truth: [mcp_servers.*] in dotcodex/config.toml
# Codex gets them via the merge above. Claude Code needs explicit `claude mcp add`.
mcp_names=$(awk '/^\[mcp_servers\./ { gsub(/\[mcp_servers\./, ""); gsub(/\]/, ""); print }' "$DOTFILES_DIR/dotcodex/config.toml")
if [ -n "$mcp_names" ] && command -v claude &>/dev/null; then
    echo ""
    echo "Setting up MCP servers for Claude Code..."
    echo "$mcp_names" | while read -r name; do
        cmd=$(awk -v s="[mcp_servers.$name]" '
            $0 == s { found=1; next }
            /^\[/ { found=0 }
            found && /^command/ { gsub(/.*= *"/, ""); gsub(/"/, ""); print }
        ' "$DOTFILES_DIR/dotcodex/config.toml")
        args=$(awk -v s="[mcp_servers.$name]" '
            $0 == s { found=1; next }
            /^\[/ { found=0 }
            found && /^args/ { gsub(/.*= *\[/, ""); gsub(/\]/, ""); gsub(/"/, ""); gsub(/, */, " "); print }
        ' "$DOTFILES_DIR/dotcodex/config.toml")
        if [ -n "$cmd" ]; then
            claude mcp add --scope user "$name" -- $cmd $args 2>/dev/null && echo "  Added MCP server: $name" || echo "  MCP server already configured: $name"
        fi
    done
elif [ -n "$mcp_names" ]; then
    echo ""
    echo "MCP servers to set up (install Claude Code first, then re-run):"
    echo "$mcp_names" | while read -r name; do echo "  - $name"; done
fi

# Enable pnpm via corepack (requires mise-managed node)
if command -v mise &>/dev/null; then
    echo ""
    echo "Setting up mise tools and pnpm..."
    mise install
    corepack enable pnpm
fi

echo ""
echo "Done."

# Remind about apps that need manual installation
manual=$(grep '^# Manual install:' "$DOTFILES_DIR/Brewfile" | sed 's/^# Manual install: //')
if [ -n "$manual" ]; then
    echo ""
    echo "The following apps need manual installation:"
    echo "$manual" | while read -r app; do
        echo "  - $app"
    done
fi

if [ -f "$DOTFILES_DIR/scripts/setup-gog.sh" ]; then
    echo ""
    echo "Optional: Run ./scripts/setup-gog.sh to configure gog CLI (Gmail/Calendar access)"
fi
