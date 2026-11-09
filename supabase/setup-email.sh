#!/usr/bin/env bash
# Sets up all EcoFun email on a Supabase project in one go:
#   1. applies supabase/schema.sql and supabase/secrets.local.sql (email outbox, triggers, Vault secrets)
#   2. stores the Gmail SMTP secrets for the ecofun-mailer Edge Function and deploys it
#   3. points Supabase Auth at Gmail SMTP and installs the EcoFun code-email templates
#   4. optional: --preview sends one sample of each app email to SMTP_USER
#
# Needs: bash, curl, jq, deno, npx (Node). Settings come from supabase/mail.local.env (git-ignored).
# Usage:  bash supabase/setup-email.sh [--preview] [--skip-schema]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ENV_FILE="supabase/mail.local.env"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE (copy supabase/mail.example.env)"; exit 1; }
set -a; source "$ENV_FILE"; set +a

PREVIEW=0; SKIP_SCHEMA=0
for arg in "$@"; do
  case "$arg" in
    --preview) PREVIEW=1 ;;
    --skip-schema) SKIP_SCHEMA=1 ;;
    *) echo "Unknown option $arg"; exit 1 ;;
  esac
done

: "${SUPABASE_PROJECT_REF:?set SUPABASE_PROJECT_REF}"
: "${SUPABASE_ACCESS_TOKEN:?set SUPABASE_ACCESS_TOKEN (https://supabase.com/dashboard/account/tokens)}"
: "${SMTP_USER:?set SMTP_USER}"
: "${SMTP_PASS:?set SMTP_PASS}"
: "${MAILER_SECRET:?set MAILER_SECRET}"
SMTP_PASS="${SMTP_PASS// /}"
MAIL_FROM_NAME="${MAIL_FROM_NAME:-EcoFun}"
API="https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF"
PUBLISHABLE_KEY="$(grep -E '^SUPABASE_PUBLISHABLE_KEY=' assets/config/.env | cut -d= -f2- | tr -d '[:space:]')"
[[ -n "$PUBLISHABLE_KEY" ]] || { echo "SUPABASE_PUBLISHABLE_KEY missing in assets/config/.env"; exit 1; }

api() { # method path [json-body-file]
  local method="$1" path="$2" body="${3:-}" out code
  out="$(mktemp)"
  if [[ -n "$body" ]]; then
    code=$(curl -sS -o "$out" -w '%{http_code}' -X "$method" "$API$path" \
      -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -H "Content-Type: application/json" --data-binary "@$body")
  else
    code=$(curl -sS -o "$out" -w '%{http_code}' -X "$method" "$API$path" -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN")
  fi
  if [[ "$code" -ge 300 ]]; then echo "  ✗ $method $path → HTTP $code: $(head -c 600 "$out")"; rm -f "$out"; return 1; fi
  cat "$out"; rm -f "$out"
}

run_sql_file() {
  local tmp; tmp="$(mktemp)"
  jq -Rs '{query: .}' < "$1" > "$tmp"
  api POST /database/query "$tmp" > /dev/null
  rm -f "$tmp"
}

echo "▸ Checking access to project $SUPABASE_PROJECT_REF"
api GET "" | jq -r '"  ✓ " + .name + " (" + .region + ")"'

if [[ $SKIP_SCHEMA -eq 0 ]]; then
  echo "▸ Applying supabase/schema.sql (takes up to a minute: it also refreshes the news)"
  run_sql_file supabase/schema.sql && echo "  ✓ schema up to date"
  echo "▸ Applying supabase/secrets.local.sql (NVIDIA key + mailer secrets → Vault)"
  run_sql_file supabase/secrets.local.sql && echo "  ✓ Vault secrets stored"
fi

echo "▸ Storing Edge Function secrets"
tmp="$(mktemp)"
jq -n --arg u "$SMTP_USER" --arg p "$SMTP_PASS" --arg s "$MAILER_SECRET" --arg k "$PUBLISHABLE_KEY" --arg n "$MAIL_FROM_NAME" \
  '[{name:"SMTP_USER",value:$u},{name:"SMTP_PASS",value:$p},{name:"MAILER_SECRET",value:$s},{name:"ECOFUN_DB_KEY",value:$k},{name:"MAIL_FROM_NAME",value:$n}]' > "$tmp"
api POST /secrets "$tmp" > /dev/null && echo "  ✓ SMTP_USER, SMTP_PASS, MAILER_SECRET, ECOFUN_DB_KEY, MAIL_FROM_NAME"
rm -f "$tmp"

echo "▸ Deploying the ecofun-mailer Edge Function"
SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN" npx -y supabase@latest functions deploy ecofun-mailer \
  --project-ref "$SUPABASE_PROJECT_REF" --no-verify-jwt --use-api --yes
echo "  ✓ deployed"

echo "▸ Building the auth email templates"
deno run --allow-read --allow-write=supabase/email-templates supabase/email-templates/build.ts > /dev/null
echo "  ✓ supabase/email-templates/*.html"

echo "▸ Configuring Supabase Auth: Gmail SMTP + EcoFun templates"
tmp="$(mktemp)"
jq -n --arg host smtp.gmail.com --arg port 465 --arg u "$SMTP_USER" --arg p "$SMTP_PASS" --arg n "$MAIL_FROM_NAME" '{
    smtp_host: $host, smtp_port: $port, smtp_user: $u, smtp_pass: $p,
    smtp_admin_email: $u, smtp_sender_name: $n, smtp_max_frequency: 30,
    rate_limit_email_sent: 100,
    mailer_autoconfirm: false,
    mailer_otp_length: 6, mailer_otp_exp: 3600,
    mailer_secure_email_change_enabled: true
  }' > "$tmp"
for key in $(jq -r 'keys[]' supabase/email-templates/manifest.json); do
  file="supabase/email-templates/$(jq -r --arg k "$key" '.[$k].file' supabase/email-templates/manifest.json)"
  subject="$(jq -r --arg k "$key" '.[$k].subject' supabase/email-templates/manifest.json)"
  next="$(mktemp)"
  jq --arg k "$key" --arg s "$subject" --rawfile html "$file" \
    '. + {("mailer_subjects_" + $k): $s, ("mailer_templates_" + $k + "_content"): $html}' "$tmp" > "$next"
  mv "$next" "$tmp"
done
api PATCH /config/auth "$tmp" > /dev/null && echo "  ✓ sender: $MAIL_FROM_NAME <$SMTP_USER> · confirm email ON · 6-digit codes · 6 templates"
rm -f "$tmp"

if [[ $PREVIEW -eq 1 ]]; then
  echo "▸ Sending a preview of every app email to $SMTP_USER"
  curl -sS -X POST "https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/ecofun-mailer" \
    -H "x-mailer-secret: $MAILER_SECRET" -H "Content-Type: application/json" \
    --data "$(jq -n --arg to "$SMTP_USER" '{preview_to: $to}')" | jq .
fi

echo "✓ EcoFun email is set up."
