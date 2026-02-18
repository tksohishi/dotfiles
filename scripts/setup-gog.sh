#!/bin/bash
set -euo pipefail

# Google Cloud project + gog CLI setup with 1Password credential backup.
# Idempotent: safe to re-run. Manual steps required for OAuth consent screen
# and credential creation (Google Cloud Console limitation).
#
# Override defaults with env vars:
#   GOG_PROJECT_ID  - Google Cloud project ID (default: gogcli-personal)
#   OP_VAULT        - 1Password vault name (default: Private)

PROJECT_ID="${GOG_PROJECT_ID:-gogcli-personal}"
OP_VAULT="${OP_VAULT:-Private}"

# ── Prerequisites ─────────────────────────────────────────────
echo "Checking prerequisites..."

missing=()
for cmd in gcloud gog op; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing required tools: ${missing[*]}"
    echo "Run: brew bundle --no-upgrade"
    exit 1
fi

echo "All prerequisites found."

# ── Google Cloud auth ─────────────────────────────────────────
if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | grep -q .; then
    echo ""
    echo "No active gcloud account. Logging in..."
    gcloud auth login
fi

ACCOUNT=$(gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | head -1)
echo "Using gcloud account: $ACCOUNT"

# ── Create project ────────────────────────────────────────────
echo ""
if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    echo "Project '$PROJECT_ID' already exists, skipping creation."
else
    echo "Creating project '$PROJECT_ID'..."
    gcloud projects create "$PROJECT_ID" --name="gog CLI"
fi

gcloud config set project "$PROJECT_ID" 2>/dev/null

# ── Enable APIs ───────────────────────────────────────────────
echo ""
echo "Enabling Gmail and Calendar APIs..."
gcloud services enable gmail.googleapis.com calendar-json.googleapis.com

# ── OAuth consent screen (manual) ────────────────────────────
echo ""
echo "============================================================"
echo "MANUAL STEP: Configure OAuth consent screen"
echo "============================================================"
echo ""
echo "Open this URL:"
echo "  https://console.cloud.google.com/apis/credentials/consent?project=$PROJECT_ID"
echo ""
echo "Settings:"
echo "  User Type: External"
echo "  App name: gog CLI"
echo "  User support email: $ACCOUNT"
echo "  Developer contact email: $ACCOUNT"
echo "  Scopes: skip (gog handles scopes at auth time)"
echo "  Test users: add $ACCOUNT"
echo "  Publishing status: leave as Testing"
echo ""
read -rp "Press Enter when the consent screen is configured..."

# ── Create OAuth client (manual) ─────────────────────────────
echo ""
echo "============================================================"
echo "MANUAL STEP: Create OAuth client credentials"
echo "============================================================"
echo ""
echo "Open this URL:"
echo "  https://console.cloud.google.com/apis/credentials/oauthclient?project=$PROJECT_ID"
echo ""
echo "Settings:"
echo "  Application type: Desktop app"
echo "  Name: gog CLI"
echo ""
echo "After creating, click 'Download JSON' to save the credentials file."
echo ""
read -rp "Press Enter when you have downloaded the credentials JSON..."

# ── Locate credentials JSON ──────────────────────────────────
echo ""
DEFAULT_DL="$HOME/Downloads"
read -rp "Path to downloaded credentials JSON [$DEFAULT_DL/client_secret_*.json]: " CRED_PATH
CRED_PATH="${CRED_PATH:-$(ls -t "$DEFAULT_DL"/client_secret_*.json 2>/dev/null | head -1)}"

if [ -z "$CRED_PATH" ] || [ ! -f "$CRED_PATH" ]; then
    echo "Error: credentials file not found at '$CRED_PATH'"
    exit 1
fi

echo "Using credentials: $CRED_PATH"

# ── Store in 1Password ────────────────────────────────────────
echo ""
echo "Storing credentials in 1Password (vault: $OP_VAULT)..."

OP_ITEM_TITLE="gog CLI OAuth Credentials ($PROJECT_ID)"

if op item get "$OP_ITEM_TITLE" --vault "$OP_VAULT" &>/dev/null; then
    echo "1Password item '$OP_ITEM_TITLE' already exists, updating..."
    op item edit "$OP_ITEM_TITLE" \
        --vault "$OP_VAULT" \
        "credentials_json[file]=$CRED_PATH"
else
    op item create \
        --category "API Credential" \
        --title "$OP_ITEM_TITLE" \
        --vault "$OP_VAULT" \
        "credentials_json[file]=$CRED_PATH"
fi

echo "Credentials stored in 1Password."

# ── Configure gog ─────────────────────────────────────────────
echo ""
echo "Configuring gog with credentials..."
gog auth credentials "$CRED_PATH"

echo ""
read -rp "Gmail address to authorize [$ACCOUNT]: " GMAIL_ADDR
GMAIL_ADDR="${GMAIL_ADDR:-$ACCOUNT}"

echo "Authorizing $GMAIL_ADDR for Gmail and Calendar..."
gog auth add "$GMAIL_ADDR" --services gmail,calendar

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "Setup complete!"
echo "============================================================"
echo ""
echo "Test commands:"
echo "  gog gmail search 'newer_than:1d' --max 5 --json"
echo "  gog calendar events --today --json"
echo "  gog auth status"
echo ""
echo "To recover credentials on another machine:"
echo "  op read 'op://$OP_VAULT/$OP_ITEM_TITLE/credentials_json' > /tmp/creds.json"
echo "  gog auth credentials /tmp/creds.json"
echo "  gog auth add YOUR_EMAIL --services gmail,calendar"
echo "  rm /tmp/creds.json"
