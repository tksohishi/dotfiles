#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/dotclaude/commands"
GEMINI_DIR="$ROOT_DIR/dotgemini/commands"
CODEX_SKILLS_DIR="$ROOT_DIR/dotcodex/skills/.dotfiles"

usage() {
    cat <<'EOF'
Usage:
  scripts/agent-commands.sh sync
  scripts/agent-commands.sh create <name>
  scripts/agent-commands.sh delete <name>
  scripts/agent-commands.sh list

Source of truth:
  dotclaude/commands/*.md

Generated targets:
  dotgemini/commands/*.toml
  dotcodex/skills/.dotfiles/*/SKILL.md
EOF
}

validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
        echo "Invalid command name: $name"
        echo "Allowed pattern: ^[a-z0-9][a-z0-9._-]*$"
        exit 1
    fi
}

escape_toml_basic() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

escape_yaml_double() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

extract_parts() {
    local input_file="$1"
    local frontmatter_file="$2"
    local body_file="$3"

    : >"$frontmatter_file"
    : >"$body_file"

    local has_frontmatter=0
    local in_frontmatter=0
    local first_line=1

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$first_line" -eq 1 ]; then
            first_line=0
            if [ "$line" = "---" ]; then
                has_frontmatter=1
                in_frontmatter=1
                continue
            fi
        fi

        if [ "$has_frontmatter" -eq 1 ] && [ "$in_frontmatter" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_frontmatter=0
                continue
            fi
            printf '%s\n' "$line" >>"$frontmatter_file"
            continue
        fi

        printf '%s\n' "$line" >>"$body_file"
    done <"$input_file"
}

resolve_description() {
    local name="$1"
    local frontmatter_file="$2"
    local body_file="$3"
    local description

    description="$(sed -n 's/^description:[[:space:]]*//p' "$frontmatter_file" | head -n1)"
    description="${description%\"}"
    description="${description#\"}"
    description="${description%\'}"
    description="${description#\'}"

    if [ -z "$description" ]; then
        description="$(sed -n 's/^# [[:space:]]*//p' "$body_file" | head -n1)"
    fi

    if [ -z "$description" ]; then
        description="Command: /$name"
    fi

    printf '%s' "$description"
}

generate_gemini_command() {
    local name="$1"
    local description="$2"
    local body_file="$3"
    local output_file="$GEMINI_DIR/$name.toml"

    {
        printf 'description = "%s"\n' "$(escape_toml_basic "$description")"
        printf 'prompt = """\n'
        while IFS= read -r line || [ -n "$line" ]; do
            printf '%s\n' "$(escape_toml_basic "$line")"
        done <"$body_file"
        printf '"""\n'
    } >"$output_file"
}

generate_codex_skill() {
    local name="$1"
    local description="$2"
    local body_file="$3"
    local skill_dir="$CODEX_SKILLS_DIR/$name"
    local output_file="$skill_dir/SKILL.md"

    mkdir -p "$skill_dir"

    {
        printf -- '---\n'
        printf 'name: "%s"\n' "$(escape_yaml_double "$name")"
        printf 'description: "%s"\n' "$(escape_yaml_double "$description")"
        printf -- '---\n\n'
        printf 'Use this skill when the user asks to run `/%s`.\n\n' "$name"
        cat "$body_file"
    } >"$output_file"
}

sync_commands() {
    mkdir -p "$GEMINI_DIR" "$CODEX_SKILLS_DIR"
    find "$GEMINI_DIR" -type f -name '*.toml' -delete
    find "$CODEX_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

    local tmp_frontmatter
    local tmp_body
    tmp_frontmatter="$(mktemp)"
    tmp_body="$(mktemp)"
    local source_file
    for source_file in "$SOURCE_DIR"/*.md; do
        [ -e "$source_file" ] || continue
        local name
        name="$(basename "$source_file" .md)"

        extract_parts "$source_file" "$tmp_frontmatter" "$tmp_body"
        local description
        description="$(resolve_description "$name" "$tmp_frontmatter" "$tmp_body")"

        generate_gemini_command "$name" "$description" "$tmp_body"
        generate_codex_skill "$name" "$description" "$tmp_body"
    done

    rm -f "$tmp_frontmatter" "$tmp_body"
}

create_command() {
    local name="$1"
    validate_name "$name"

    local source_file="$SOURCE_DIR/$name.md"
    if [ -e "$source_file" ]; then
        echo "Command already exists: $source_file"
        exit 1
    fi

    mkdir -p "$SOURCE_DIR"

    cat >"$source_file" <<EOF
---
description: Describe what /$name should do
argument-hint: <args>
allowed-tools: [Read, Edit, Bash]
---

# /$name

Describe the workflow for /$name.
EOF

    sync_commands
    echo "Created: $source_file"
}

delete_command() {
    local name="$1"
    validate_name "$name"

    local source_file="$SOURCE_DIR/$name.md"
    if [ ! -e "$source_file" ]; then
        echo "Command does not exist: $source_file"
        exit 1
    fi

    rm -f "$source_file"
    sync_commands
    echo "Deleted: $source_file"
}

list_commands() {
    local source_file
    for source_file in "$SOURCE_DIR"/*.md; do
        [ -e "$source_file" ] || continue
        basename "$source_file" .md
    done
}

main() {
    local subcommand="${1:-}"
    case "$subcommand" in
    sync)
        sync_commands
        ;;
    create)
        [ $# -eq 2 ] || {
            usage
            exit 1
        }
        create_command "$2"
        ;;
    delete)
        [ $# -eq 2 ] || {
            usage
            exit 1
        }
        delete_command "$2"
        ;;
    list)
        list_commands
        ;;
    *)
        usage
        exit 1
        ;;
    esac
}

main "$@"
