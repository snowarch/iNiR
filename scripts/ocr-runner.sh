#!/usr/bin/env bash
set -u

image=${1:-}
requested=${2:-auto}

if [[ -z "$image" || ! -f "$image" ]]; then
  printf 'OCR input image is missing\n' >&2
  exit 2
fi
if ! command -v tesseract >/dev/null 2>&1; then
  printf 'tesseract is not installed\n' >&2
  exit 127
fi

locale_lang() {
  local locale=${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}
  case "$locale" in
    ja*|JA*) printf 'jpn' ;;
    ru*|RU*) printf 'rus' ;;
    zh_TW*|zh_HK*|zh_MO*|ZH_TW*|ZH_HK*|ZH_MO*) printf 'chi_tra' ;;
    zh*|ZH*) printf 'chi_sim' ;;
    es*|ES*) printf 'spa' ;;
    *) printf 'eng' ;;
  esac
}

auto_mode=false
if [[ "$requested" == auto || -z "$requested" ]]; then
  auto_mode=true
  requested=$(locale_lang)
fi

# Keep a user-owned tessdata cache so existing installs can gain a language on
# first use without sudo. Distro packages remain the preferred install path;
# system models are symlinked into this cache and only missing models download.
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
tessdata_dir=${INIR_TESSDATA_DIR:-$data_home/inir/tessdata}
mkdir -p "$tessdata_dir" || {
  printf 'Could not create iNiR OCR data directory: %s\n' "$tessdata_dir" >&2
  exit 5
}

system_tessdata=$(tesseract --list-langs 2>&1 | sed -n '1s/.*"\(.*\)".*/\1/p')

ensure_language() {
  local lang=$1 target="$tessdata_dir/$lang.traineddata" tmp url
  [[ -s "$target" ]] && return 0

  if [[ -n "$system_tessdata" && -s "$system_tessdata/$lang.traineddata" ]]; then
    ln -sf "$system_tessdata/$lang.traineddata" "$target"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || return 1
  tmp="$target.part.$$"
  for url in \
    "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/$lang.traineddata" \
    "https://cdn.jsdelivr.net/gh/tesseract-ocr/tessdata_fast@main/$lang.traineddata"; do
    if curl -fL --connect-timeout 8 --retry 2 --retry-delay 1 -o "$tmp" "$url" >/dev/null 2>&1 \
        && [[ -s "$tmp" ]]; then
      mv -f "$tmp" "$target"
      return 0
    fi
  done
  rm -f "$tmp"
  return 1
}

IFS='+' read -r -a wanted <<< "$requested"
selected=()
missing=()
for lang in "${wanted[@]}"; do
  [[ -n "$lang" ]] || continue
  if ensure_language "$lang"; then
    selected+=("$lang")
  else
    missing+=("$lang")
  fi
done

# Auto may degrade to an existing English model. Explicit language choices must
# never silently OCR Japanese/Chinese/Russian as English.
if [[ "$auto_mode" == true && ${#selected[@]} == 0 ]]; then
  if ensure_language eng; then
    selected=(eng)
  fi
elif [[ "$auto_mode" == false && ${#missing[@]} -gt 0 ]]; then
  printf 'Could not provision Tesseract language data: %s. Check the network or install the distro language pack.\n' \
    "$(IFS=+; printf '%s' "${missing[*]}")" >&2
  exit 4
fi

if ((${#selected[@]} == 0)); then
  printf 'No usable Tesseract language data is available\n' >&2
  exit 3
fi

langs=$(IFS=+; printf '%s' "${selected[*]}")

# Pick a page segmentation mode from the actual selection geometry. Tesseract's
# fully automatic default is good for documents but often drops characters in
# the small, line-like regions produced by a screen snipping tool.
psm=6
img_w=0
img_h=0
if command -v magick >/dev/null 2>&1; then
  read -r img_w img_h < <(magick identify -format '%w %h' "$image" 2>/dev/null || printf '0 0')
fi
case "$langs" in
  *jpn_vert*|*chi_sim_vert*|*chi_tra_vert*) psm=5 ;;
  *)
    if (( img_h > 0 && img_w > img_h * 3 )); then
      psm=7
    elif (( img_w > 0 && img_h > img_w * 2 )); then
      psm=6
    fi
    ;;
esac

# Small UI text benefits from a light 2x upscale. Avoid thresholding: antialiased
# browser/game text and colored glyphs lose strokes under hard binarization.
work_image="$image"
tmp_image=""
if command -v magick >/dev/null 2>&1 && (( img_h > 0 && img_h < 140 )); then
  tmp_image="${TMPDIR:-/tmp}/inir-ocr-${BASHPID:-$$}.png"
  if magick "$image" -filter Lanczos -resize 200% -colorspace Gray -contrast-stretch 0x4% -sharpen 0x0.55 "$tmp_image" 2>/dev/null; then
    work_image="$tmp_image"
  else
    rm -f "$tmp_image"
    tmp_image=""
  fi
fi

cleanup_ocr() {
  [[ -n "$tmp_image" ]] && rm -f "$tmp_image"
}
trap cleanup_ocr EXIT

# Japanese/Chinese OCR can emit spaces between individual glyphs. The dictionary
# layer normalizes those selectively; keeping raw stdout here preserves useful
# whitespace for every other language and for the clipboard.
tesseract "$work_image" stdout --tessdata-dir "$tessdata_dir" -l "$langs" --psm "$psm"
