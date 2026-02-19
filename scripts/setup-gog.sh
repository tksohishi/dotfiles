#!/bin/bash
set -euo pipefail

# Google Cloud project + gog CLI setup with 1Password credential backup.
# Idempotent: safe to re-run. Manual steps required for OAuth consent screen
# and credential creation (Google Cloud Console limitation).
#
# Override defaults with env vars:
#   GOG_PROJECT_ID  - Google Cloud project ID (prompted if not set)
#   OP_VAULT        - 1Password vault name (default: Private)

export OP_BIOMETRIC_UNLOCK_ENABLED=true
OP_VAULT="${OP_VAULT:-Private}"
OP_ITEM="gogcli-oauth-json"

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

# Verify 1Password CLI is connected to the desktop app
if ! op account list &>/dev/null; then
    echo ""
    echo "1Password CLI is not connected. To set up:"
    echo "  1. Open the 1Password desktop app"
    echo "  2. Go to Settings > Developer"
    echo "  3. Turn on 'Integrate with 1Password CLI'"
    echo "  4. Re-run this script"
    exit 1
fi

# Select 1Password account if multiple exist and OP_ACCOUNT is not set
if [ -z "${OP_ACCOUNT:-}" ]; then
    account_count=$(op account list --format json | jq 'length')
    if [ "$account_count" -gt 1 ]; then
        echo ""
        echo "Multiple 1Password accounts found:"
        op account list
        echo ""
        read -rp "Enter the account URL to use (e.g. myaccount.1password.com): " OP_ACCOUNT
        export OP_ACCOUNT
    fi
fi

echo "All prerequisites found."

# ── Resolve project ID ────────────────────────────────────────
if [ -n "${GOG_PROJECT_ID:-}" ]; then
    PROJECT_ID="$GOG_PROJECT_ID"
elif op item get "$OP_ITEM" --vault "$OP_VAULT" --fields project_id --format json 2>/dev/null | jq -re '.value' &>/dev/null; then
    PROJECT_ID=$(op item get "$OP_ITEM" --vault "$OP_VAULT" --fields project_id --format json | jq -r '.value')
    echo "Using project ID from 1Password: $PROJECT_ID"
else
    gcloud_project=$(gcloud config get-value project 2>/dev/null || true)
    if [ -n "$gcloud_project" ]; then
        read -rp "Google Cloud project ID [$gcloud_project]: " PROJECT_ID
        PROJECT_ID="${PROJECT_ID:-$gcloud_project}"
    else
        read -rp "Google Cloud project ID (must be globally unique): " PROJECT_ID
    fi
    if [ -z "$PROJECT_ID" ]; then
        echo "Error: project ID is required"
        exit 1
    fi
fi

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
echo "If the consent screen is not yet configured:"
echo "  a. Open: https://console.cloud.google.com/auth/overview?project=$PROJECT_ID"
echo "  b. If you see 'Get Started', click it and fill in:"
echo "     App name: gog CLI"
echo "     User support email: $ACCOUNT"
echo "     Audience: External"
echo "     Developer contact email: $ACCOUNT"
echo "     Agree to policy, click Create"
echo "  c. If the overview already shows 'OAuth Overview', the consent screen"
echo "     is configured. Verify settings at Branding in the left sidebar."
echo ""
echo "Then add yourself as a test user:"
echo "  https://console.cloud.google.com/auth/audience?project=$PROJECT_ID"
echo "  Click 'Add users', enter: $ACCOUNT"
echo ""
read -rp "Press Enter when the consent screen and test user are configured..."

# ── Create OAuth client (manual) ─────────────────────────────
echo ""
echo "============================================================"
echo "MANUAL STEP: Create OAuth client credentials"
echo "============================================================"
echo ""
echo "1. Open the Clients page:"
echo "   https://console.cloud.google.com/auth/clients?project=$PROJECT_ID"
echo ""
echo "2. Click 'Create Client'"
echo "   Application type: Desktop app"
echo "   Name: gog CLI"
echo "   Click Create"
echo ""
echo "3. Download the JSON immediately from the creation dialog."
echo "   (The client secret is only fully visible at creation time.)"
echo ""
read -rp "Press Enter when you have downloaded the credentials JSON..."

# ── Locate credentials JSON ──────────────────────────────────
echo ""
DEFAULT_DL="$HOME/Downloads"
CRED_PATH=""

# Auto-detect the most recent client_secret JSON in Downloads
auto_path=$(ls -t "$DEFAULT_DL"/client_secret_*.json 2>/dev/null | head -1 || true)

while true; do
    if [ -n "$auto_path" ]; then
        echo "Found: $auto_path"
        read -rp "Use this file? [Y/n] " use_auto
        if [[ "${use_auto:-y}" =~ ^[Yy]$ ]]; then
            CRED_PATH="$auto_path"
            break
        fi
    else
        echo "No client_secret_*.json found in $DEFAULT_DL"
    fi

    read -rp "Path to credentials JSON: " CRED_PATH

    if [ -n "$CRED_PATH" ] && [ -f "$CRED_PATH" ]; then
        break
    fi

    echo "File not found: '$CRED_PATH'"
    echo "Please try again."
    echo ""
done

echo "Using credentials: $CRED_PATH"

# ── Store in 1Password ────────────────────────────────────────
echo ""
echo "Storing credentials in 1Password (vault: $OP_VAULT)..."

read -rp "Gmail address to store in 1Password [$ACCOUNT]: " GMAIL_ADDR
GMAIL_ADDR="${GMAIL_ADDR:-$ACCOUNT}"

if op item get "$OP_ITEM" --vault "$OP_VAULT" &>/dev/null; then
    echo "1Password item '$OP_ITEM' already exists, updating..."
    op item edit "$OP_ITEM" \
        --vault "$OP_VAULT" \
        "credentials_json[file]=$CRED_PATH" \
        "email[text]=$GMAIL_ADDR" \
        "project_id[text]=$PROJECT_ID"
else
    op item create \
        --category "API Credential" \
        --title "$OP_ITEM" \
        --vault "$OP_VAULT" \
        "credentials_json[file]=$CRED_PATH" \
        "email[text]=$GMAIL_ADDR" \
        "project_id[text]=$PROJECT_ID"
fi

echo "Credentials stored in 1Password."

# ── Configure gog ─────────────────────────────────────────────
echo ""
echo "Configuring gog with credentials..."
gog auth credentials set "$CRED_PATH"

rm "$CRED_PATH"
echo "Removed $CRED_PATH (backed up in 1Password and gog config)"

echo ""
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
echo "  op read 'op://$OP_VAULT/$OP_ITEM/credentials_json' > /tmp/creds.json"
echo "  gog auth credentials set /tmp/creds.json"
echo "  gog auth add \$(op read 'op://$OP_VAULT/$OP_ITEM/email') --services gmail,calendar"
echo "  rm /tmp/creds.json"
