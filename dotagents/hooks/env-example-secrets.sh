#!/bin/bash
# Pre-hook: deny writing an un-rotatable secret into a committed env template
# (.env.example / .env.sample / .env.template).
#
# A leaked API token is rotated; a leaked crypto private key, mnemonic, or
# seed phrase is not, because the account it controls is the key. Those must
# never land in a template file that git tracks. The schema entry itself
# (`PRIVATE_KEY=`, `PRIVATE_KEY=<your key>`, `PRIVATE_KEY=0x...`) is fine and
# is what the template is for; the deny fires only when such a key carries a
# value that looks real.
#
# Scope: Write content, Edit/NotebookEdit new_string, and Bash commands that
# name a template file (heredoc, echo >>, tee, sed -i). Codex has no
# Write/Edit hooks, so the Bash path is its only coverage.

TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // ""')

TEMPLATE_RE='\.env\.(example|sample|template)$'
TEMPLATE_IN_CMD_RE='\.env\.(example|sample|template)([^A-Za-z0-9_.]|$)'

case "$TOOL_NAME" in
  Write)
    FILE=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // ""')
    [[ "$FILE" =~ $TEMPLATE_RE ]] || exit 0
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.content // ""')
    WHERE="$FILE"
    ;;
  Edit|NotebookEdit)
    FILE=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')
    [[ "$FILE" =~ $TEMPLATE_RE ]] || exit 0
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.new_string // .tool_input.new_source // ""')
    WHERE="$FILE"
    ;;
  Bash)
    CONTENT=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // ""')
    [[ "$CONTENT" =~ $TEMPLATE_IN_CMD_RE ]] || exit 0
    WHERE="a command that writes an env template"
    ;;
  *)
    exit 0
    ;;
esac

# Key names whose value cannot be rotated: crypto private keys, mnemonics,
# seed phrases, keystore material. Matched as whole `_`-separated words so
# PUBLIC_KEY and API_KEY don't hit; any `PK` word (PK, PK_MAIN, STRIPE_PK)
# does, since PK is the user's convention for wallet keys.
KEY_RE='(^|[[:space:]"'"'"'])(export[[:space:]]+)?(([A-Za-z0-9_]*_)?(PRIVATE_KEY|PRIV_KEY|PRIVKEY|PK|SECRET_KEY_HEX|MNEMONIC|SEED_PHRASE|SEED_WORDS|SEED|KEYSTORE|KEYSTORE_JSON|WALLET_KEY|SIGNER_KEY|DEPLOYER_KEY|OPERATOR_KEY|VALIDATOR_KEY)(_[A-Za-z0-9_]*)?)[[:space:]]*='

# Values that are obviously placeholders: empty, angle-bracket or brace
# templates, your-/my-/example/changeme/placeholder/todo/xxx, an ellipsis, or
# all-zero hex.
PLACEHOLDER_RE='^["'"'"']?(<[^>]*>|\{\{?[^}]*\}?\}|\$\{[^}]*\}|(your|my|sample|example|dummy|fake|test|placeholder|changeme|change_me|replace_me|replaceme|todo|tbd|xxx+|\.\.\.|0x\.\.\.|0x0+|0x[xX]+|\*+|redacted|none|null|undefined)([-_ .][A-Za-z0-9_ .-]*)?)?["'"'"']?[[:space:]]*(#.*)?$'

# Values that look like the real thing: 0x + 64 hex (EVM key), 64+ hex, a
# base58/base64-ish run of 40+ chars (Solana, keystore blobs), 12/24
# lowercase words (BIP-39 mnemonic), or a PEM block.
REAL_RE='^["'"'"']?(0x[0-9a-fA-F]{64}|[0-9a-fA-F]{64,}|[A-Za-z0-9+/=_-]{40,}|([a-z]+[[:space:]]+){11,23}[a-z]+|-----BEGIN)'

HIT=""
while IFS= read -r line; do
  [[ "$line" =~ $KEY_RE ]] || continue
  key="${BASH_REMATCH[3]}"
  value="${line#*"${BASH_REMATCH[0]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  [[ "$value" =~ $PLACEHOLDER_RE ]] && continue
  [[ "$value" =~ $REAL_RE ]] || continue
  HIT="$key"
  break
done <<< "$CONTENT"

[ -z "$HIT" ] && exit 0

REASON="Un-rotatable secret in an env template ($WHERE): '$HIT' carries a value that looks like a real key, mnemonic, or seed phrase. Template files are committed; a crypto private key that lands in git cannot be rotated away. Leave the value empty or a placeholder (PRIVATE_KEY=<your key>), and keep the real value in .env, which the user pastes in themselves."

jq -nc --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
