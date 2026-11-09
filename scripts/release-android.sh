#!/usr/bin/env bash
# Publishes a new EcoFun Android release:
#   1. builds one universal, release-signed APK (every Android phone)
#   2. uploads it to a GitHub Release, so the permanent link serves it:
#        https://github.com/humuraelvin/EcoFun/releases/latest/download/EcoFun.apk
#   3. tells installed apps about it (Supabase table app_releases -> "Update available")
#
# Before running: bump `version:` in pubspec.yaml (e.g. 1.2.1+2011; the number after + must grow).
# Needs: git push access to the repo, android/key.properties + android/app/ecofun-release.jks (the signing key),
#        supabase/mail.local.env (SUPABASE_ACCESS_TOKEN) for step 3.
# Usage:
#   NOTES_EN="What changed" NOTES_RW="Ibyahindutse" bash scripts/release-android.sh [--force-update]
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="humuraelvin/EcoFun"
FORCE=0; [[ "${1:-}" == "--force-update" ]] && FORCE=1
[[ -f android/key.properties ]] || { echo "Missing android/key.properties (release signing key). See ~/EcoFun-signing-key/"; exit 1; }

VERSION_LINE=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
NAME=${VERSION_LINE%%+*}; CODE=${VERSION_LINE##*+}
TAG="v$NAME"
NOTES_EN=${NOTES_EN:-"Improvements and fixes."}
NOTES_RW=${NOTES_RW:-"Ibyanogejwe n'ibyakosowe."}
echo "▸ EcoFun $NAME (build $CODE)"

echo "▸ Building the universal release APK"
[[ "${SKIP_BUILD:-0}" == "1" && -f build/app/outputs/flutter-apk/app-release.apk ]] || flutter build apk --release --target-platform android-arm,android-arm64 --android-skip-build-dependency-validation >/dev/null
mkdir -p build/release
cp build/app/outputs/flutter-apk/app-release.apk build/release/EcoFun.apk
SIZE=$(du -h build/release/EcoFun.apk | cut -f1)
SHA=$(sha256sum build/release/EcoFun.apk | cut -d' ' -f1)
echo "  ✓ build/release/EcoFun.apk ($SIZE)"

LINK="https://github.com/$REPO/releases/latest/download/EcoFun.apk"
echo "▸ Publishing GitHub Release $TAG"
# The APK goes to the `apk-release` branch (a single commit, replaced each time); the workflow in
# .github/workflows/publish-apk.yml turns it into the GitHub Release with GitHub's own token.
WORK=$(mktemp -d)
mkdir -p "$WORK/.github/workflows"
cp .github/workflows/publish-apk.yml "$WORK/.github/workflows/"
cp build/release/EcoFun.apk "$WORK/EcoFun.apk"
NOTES=$(printf '### What'"'"'s new\n%s\n\n### Ibishya\n%s\n\n**Install on Android:** open %s on your phone, then tap Install.\n\nSize: %s · SHA-256: `%s`' \
  "$NOTES_EN" "$NOTES_RW" "$LINK" "$SIZE" "$SHA")
jq -n --arg n "$NAME" --argjson c "$CODE" --arg notes "$(printf '%b' "$NOTES")" \
  '{version_name:$n, version_code:$c, notes:$notes}' > "$WORK/release.json"
ORIGIN=$(git remote get-url origin)
( cd "$WORK" && git init -q -b apk-release && git add . \
  && git -c user.name="$(git -C "$OLDPWD" config user.name)" -c user.email="$(git -C "$OLDPWD" config user.email)" \
       commit -q -m "EcoFun $NAME APK" \
  && git push -q -f "$ORIGIN" apk-release )
rm -rf "$WORK"
echo "  ✓ pushed; waiting for GitHub to publish the release…"
for i in $(seq 1 40); do
  sleep 6
  CODE_HTTP=$(curl -s -o /dev/null -w '%{http_code}' -L "https://api.github.com/repos/$REPO/releases/tags/$TAG")
  if [[ "$CODE_HTTP" == "200" ]] && curl -s "https://api.github.com/repos/$REPO/releases/tags/$TAG" | jq -e '.assets[] | select(.name=="EcoFun.apk")' >/dev/null; then
    echo "  ✓ $LINK"; break
  fi
  [[ $i -eq 40 ]] && { echo "  ✗ Not published yet — check https://github.com/$REPO/actions"; exit 1; }
done

echo "▸ Announcing the update to installed apps"
T=$(grep -E '^SUPABASE_ACCESS_TOKEN=' supabase/mail.local.env | cut -d= -f2-)
REF=$(grep -E '^SUPABASE_PROJECT_REF=' supabase/mail.local.env | cut -d= -f2-)
MIN=0; [[ $FORCE -eq 1 ]] && MIN=$CODE
# Dollar-quoted SQL ($v$...$v$) needs no escaping of the release notes.
SQL="insert into public.app_releases (platform, version_code, version_name, download_url, min_version_code, notes_en, notes_rw, released_at)
values (\$v\$android\$v\$, $CODE, \$v\$$NAME\$v\$, \$v\$$LINK\$v\$, $MIN, \$v\$$NOTES_EN\$v\$, \$v\$$NOTES_RW\$v\$, now())
on conflict (platform) do update set version_code = excluded.version_code, version_name = excluded.version_name,
  download_url = excluded.download_url, min_version_code = excluded.min_version_code,
  notes_en = excluded.notes_en, notes_rw = excluded.notes_rw, released_at = now();"
curl -sS -X POST "https://api.supabase.com/v1/projects/$REF/database/query" -H "Authorization: Bearer $T" \
  -H "Content-Type: application/json" -d "$(jq -n --arg q "$SQL" '{query:$q}')" >/dev/null
echo "  ✓ apps on older versions will now show \"Update available\""
echo "✓ Released EcoFun $NAME"
