#!/usr/bin/env bash
# Publishes a new EcoFun Android release:
#   1. builds one universal, release-signed APK (every Android phone)
#   2. uploads it to a GitHub Release, so the permanent link serves it:
#        https://github.com/humuraelvin/EcoFun/releases/latest/download/EcoFun.apk
#   3. tells installed apps about it (Supabase table app_releases -> "Update available")
#
# Before running: bump `version:` in pubspec.yaml (e.g. 1.2.1+2011; the number after + must grow).
# Needs: android/key.properties + android/app/ecofun-release.jks (the signing key),
#        GITHUB_TOKEN (fine-grained token with "Contents: read and write" on humuraelvin/EcoFun),
#        supabase/mail.local.env (SUPABASE_ACCESS_TOKEN) for step 3.
# Usage:
#   GITHUB_TOKEN=github_pat_xxx NOTES_EN="What changed" NOTES_RW="Ibyahindutse" bash scripts/release-android.sh [--force-update]
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="humuraelvin/EcoFun"
FORCE=0; [[ "${1:-}" == "--force-update" ]] && FORCE=1
[[ -f android/key.properties ]] || { echo "Missing android/key.properties (release signing key). See ~/EcoFun-signing-key/"; exit 1; }
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN (github.com/settings/personal-access-tokens, Contents: read and write)}"

VERSION_LINE=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
NAME=${VERSION_LINE%%+*}; CODE=${VERSION_LINE##*+}
TAG="v$NAME"
NOTES_EN=${NOTES_EN:-"Improvements and fixes."}
NOTES_RW=${NOTES_RW:-"Ibyanogejwe n'ibyakosowe."}
echo "▸ EcoFun $NAME (build $CODE)"

echo "▸ Building the universal release APK"
flutter build apk --release --target-platform android-arm,android-arm64 --android-skip-build-dependency-validation >/dev/null
mkdir -p build/release
cp build/app/outputs/flutter-apk/app-release.apk build/release/EcoFun.apk
SIZE=$(du -h build/release/EcoFun.apk | cut -f1)
SHA=$(sha256sum build/release/EcoFun.apk | cut -d' ' -f1)
echo "  ✓ build/release/EcoFun.apk ($SIZE)"

gh() { curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

echo "▸ Publishing GitHub Release $TAG"
BODY=$(jq -n --arg en "$NOTES_EN" --arg rw "$NOTES_RW" --arg sha "$SHA" --arg size "$SIZE" \
  '"### What'"'"'s new\n" + $en + "\n\n### Ibishya\n" + $rw +
   "\n\n**Install:** open https://github.com/'"$REPO"'/releases/latest/download/EcoFun.apk on your Android phone, then tap Install.\n\nSize: " + $size + " · SHA-256: `" + $sha + "`"')
RELEASE=$(gh "https://api.github.com/repos/$REPO/releases/tags/$TAG" || true)
RID=$(echo "$RELEASE" | jq -r '.id // empty')
if [[ -z "$RID" ]]; then
  RELEASE=$(gh -X POST "https://api.github.com/repos/$REPO/releases" \
    -d "$(jq -n --arg tag "$TAG" --arg name "EcoFun $NAME" --argjson body "$BODY" \
          '{tag_name:$tag, name:$name, body:$body, draft:false, prerelease:false, make_latest:"true"}')")
  RID=$(echo "$RELEASE" | jq -r '.id // empty')
fi
[[ -n "$RID" ]] || { echo "  ✗ Could not create the release: $(echo "$RELEASE" | head -c 400)"; exit 1; }
# replace an existing EcoFun.apk asset on this release
OLD=$(gh "https://api.github.com/repos/$REPO/releases/$RID/assets" | jq -r '.[] | select(.name=="EcoFun.apk") | .id')
[[ -n "$OLD" ]] && gh -X DELETE "https://api.github.com/repos/$REPO/releases/assets/$OLD" >/dev/null
UP=$(curl -sS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary @build/release/EcoFun.apk "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=EcoFun.apk")
echo "$UP" | jq -e '.browser_download_url' >/dev/null || { echo "  ✗ Upload failed: $(echo "$UP" | head -c 400)"; exit 1; }
LINK="https://github.com/$REPO/releases/latest/download/EcoFun.apk"
echo "  ✓ $LINK"

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
