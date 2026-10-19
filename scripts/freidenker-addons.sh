#!/usr/bin/env bash
# Installs the Freidenker raid addon pack into benilla's AddOns folder: each addon at the commit we
# tested on 1.12.1 with benilla (German and English game data), fetched from its own GitHub
# repository, plus our two fixes. The addons are third-party code under their own terms (most
# state no license), which is why this fork carries this list and not their files.
#
#   scripts/freidenker-addons.sh                   into benilla-config/AddOns of this checkout
#   scripts/freidenker-addons.sh <AddOns folder>   into any other AddOns folder
#   WITH_DPSMATE=1 scripts/freidenker-addons.sh    also DPSMate, a larger second damage meter
#
# A run replaces exactly the folders below and leaves every other addon alone. Needs curl, tar
# and perl.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
if [ $# -ge 1 ]; then
  dest="$1"
elif [ -n "${BENILLA_HOME:-}" ]; then
  dest="$BENILLA_HOME/AddOns"
else
  dest="$root/benilla-config/AddOns"
fi
mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"

for tool in curl tar perl; do
  command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# fetch <owner/repo> <commit>: unpack the repository at that commit into $work/<repo>.
fetch() {
  local repo="$1" commit="$2" name="${1#*/}"
  echo "== $repo @ ${commit:0:7}"
  curl -fsSL "https://github.com/$repo/archive/$commit.tar.gz" -o "$work/$name.tar.gz"
  mkdir -p "$work/$name"
  tar -xzf "$work/$name.tar.gz" -C "$work/$name" --strip-components 1
}

# place <repo> <path in repo> <folder>: copy one addon in under the name its .toc needs.
place() {
  local name="$1" src="$2" folder="$3"
  [ -f "$work/$name/$src/$folder.toc" ] || { echo "no $folder.toc in $name/$src" >&2; exit 1; }
  rm -rf "${dest:?}/$folder"
  cp -R "$work/$name/$src" "$dest/$folder"
  rm -rf "$dest/$folder/.github"
  echo "   -> $folder"
}

fetch xorann/BigWigs 84a4af820a2baaebb4e9e445b9997f2a553d1b08
place BigWigs . BigWigs
fetch Linae-Kronos/KLH-Threat-Meter-17.35 69b05f6edf25c6c6a5bbf1ce2a902e9edab48676
place KLH-Threat-Meter-17.35 "KTM 17.35/KLHThreatMeter" KLHThreatMeter
fetch xorann/oRA2 28a373a7cdf2efb7d48229623b732bf27ddfe518
place oRA2 . oRA2
fetch dagochen/RABuff e26dea7099155e0b7b4e982d9ba5f8316d0fffe4
place RABuff . RABuffs
fetch Linae-Kronos/BananaBar 56a4355b9b71a5f2e0febe61b880e13e821f2c62
place BananaBar . Banana
fetch Zerf/Decursive c8625259ae8953a694a2b3b43f8e2faee90d8351
place Decursive . Decursive
fetch shagu/ShaguTweaks 7d670218a9b1e0a6a9a9062c0f458508398f2e48
place ShaguTweaks . ShaguTweaks
fetch shagu/ShaguScore b07d25e6a1fa30391d9dca0dd728e33a762c6711
place ShaguScore . ShaguScore
fetch yutsuku/BetterCharacterStats 20fe849a2cc81d80290a03aa43f382aebbc05ec4
place BetterCharacterStats . BetterCharacterStats
fetch shagu/ShaguDPS 79c25e60f9ab3f314d69bec3d3edcbf965b7c312
place ShaguDPS . ShaguDPS

# Decursive resets its saved output window only when it is nil; a table an older client wrote in
# its place has no AddMessage and raised `Decursive.lua:1391` at every login. Reset that too.
decursive="$dest/Decursive/Decursive.lua"
perl -pi -e 's/^(\s*if \(Dcr_Saved\.Dcr_OutputWindow == nil or not Dcr_Saved\.Dcr_OutputWindow)\) then/$1 or not Dcr_Saved.Dcr_OutputWindow.AddMessage) then/' "$decursive"
grep -q 'or not Dcr_Saved.Dcr_OutputWindow.AddMessage) then' "$decursive" \
  || { echo "the Decursive fix did not apply" >&2; exit 1; }
echo "   fixed: Decursive output window"

if [ "${WITH_DPSMATE:-0}" = 1 ]; then
  fetch tdymel/DPSMate 0ac30fdc2c4f4dcaefcea00fa7070a45da31a1dc
  for dir in "$work/DPSMate"/DPSMate*; do
    folder="$(basename "$dir")"
    case "$folder" in
      "DPSMate_!frFR" | "DPSMate_!koKR" | "DPSMate_!ruRU" | "DPSMate_!zhCN") continue ;;
    esac
    place DPSMate "$folder" "$folder"
  done
  # Its first start resets the data and reads the current buffs before it repoints its tables,
  # one line it ships commented out; with a buff up it raised `DPSMate_DataBuilder.lua:2191`.
  options="$dest/DPSMate/DPSMate_Options.lua"
  perl -0pi -e 's/--DPSMate\.DB:UpdatePointer\(\)/DPSMate.DB:UpdatePointer()/' "$options"
  [ "$(grep -c -F -e '--DPSMate.DB:UpdatePointer()' "$options")" = 1 ] \
    || { echo "the DPSMate fix did not apply" >&2; exit 1; }
  echo "   fixed: DPSMate first start"
fi

echo "done: the raid addon pack is in $dest"
echo "A running benilla loads it after /reload or the next login."
