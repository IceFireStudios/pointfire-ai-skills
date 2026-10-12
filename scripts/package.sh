#!/usr/bin/env bash
# Packages skills/pfte-translations into dist/pfte-translations.zip, the folder for every AI tool,
# and dist/pfte-translations.skill, the same archive under the name the Claude apps upload.
set -euo pipefail
cd "$(dirname "$0")/.."

SKILL=pfte-translations
DIR="skills/$SKILL"

# The Agent Skills spec requires the name to match the folder, and caps the description at 1024 characters.
name=$(sed -n 's/^name: *//p' "$DIR/SKILL.md" | head -n 1)
if [ "$name" != "$SKILL" ]; then
  echo "error: SKILL.md name '$name' doesn't match the folder '$SKILL'" >&2
  exit 1
fi
description=$(sed -n "s/^description: *'\(.*\)'$/\1/p" "$DIR/SKILL.md" | head -n 1)
if [ -z "$description" ] || [ "${#description}" -gt 1024 ]; then
  echo "error: SKILL.md description is empty or longer than 1024 characters (${#description})" >&2
  exit 1
fi

version=$(node -p "require('./.claude-plugin/plugin.json').version")

rm -rf dist
mkdir dist
(cd skills && zip -r -q -X "../dist/$SKILL.zip" "$SKILL" -x '*.DS_Store')
cp "dist/$SKILL.zip" "dist/$SKILL.skill"

echo "Packaged $SKILL $version:"
ls -l dist
