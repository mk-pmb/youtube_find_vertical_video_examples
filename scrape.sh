#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function scrape_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?

  local YT_BASEURL='https://yewtu.be/'
  local -A BKM=(
    [cc-vv]='search?q=features:creative_commons+%22vertical+video%22'
    [tq]='channel/UC0vBXGSyV14uvJ4hECDOl0Q'
    )

  local TASK="$1"; shift
  case "$TASK" in
    '-1' ) TASK='categorize_one_video';;
    '' ) TASK='suggest_and_log';;
  esac
  scrape_"$TASK" "$@" || return $?
}


function scrape_suggest_and_log () {
  scrape_suggest "$@" |& tee --append -- tmp.suggested.tsv
}


function scrape_suggest () {
  local V_IDS=()
  readarray -t V_IDS < <(scrape_all_bkm)
  local V_ID=
  for V_ID in "${V_IDS[@]}"; do
    scrape_categorize_one_video "$V_ID" || return $?
  done
}


function scrape_all_bkm () {
  local KEY=
  for KEY in "${!BKM[@]}"; do
    scrape_list bkm:"$KEY" || return $?
  done
}


function scrape_list () {
  local LU="$1"
  [ -n "$LU" ] || return 4$(echo "E: $FUNCNAME: No URL given" >&2)
  local ORIG_LU="$LU"
  printf '# scan start %(%F %T)T url:%s\n' -1 "$ORIG_LU" >&2
  [[ "$LU" == bkm:* ]] && LU="${BKM[${LU#*:}]}"
  [[ "$LU" == *'://'* ]] || LU="$YT_BASEURL${LU#/}"
  curl --silent -- "$LU" \
    | grep -oPe '<img [^<>]*>' \
    | grep -Fe ' class="thumbnail"' \
    | grep -oPe ' src="/vi/[^"/]+' \
    | cut -d / -sf 3-
  sleep 2
  printf '# scan done  %(%F %T)T url:%s\n' -1 "$ORIG_LU" >&2
}


function scrape_download_watch_page () {
  local V_ID="$1"; shift
  local BFN="tmp.cache/watch_html/$V_ID"
  mkdir --parents -- "${BFN%/*}"
  local V_URL="https://www.youtube.com/watch?v=$V_ID"
  local OPT=()
  if [ ! -s "$BFN.html" ]; then
    OPT=(
      --output-file="$BFN".$$.log \
      --output-document="$BFN".$$.tmp \
      -- "$V_URL"
      )
    wget "${OPT[@]}" || return $?$(echo "E: failed to download $V_URL" >&2)
    mv --no-target-directory -- "$BFN"{.$$.tmp,.html} || return $?$(
      echo "E: failed to store $V_URL in cache dir" >&2)
    rm -- "$BFN".$$.log
  fi

  [ -s "$BFN".init.json ] \
    || scrape_extract_init_json "$BFN".html >"$BFN".init.json \
    || return $?$(echo "E: failed to extract player init data for v=$V_ID" >&2)

  local SUF=
  for SUF in "$@"; do
    cat -- "$BFN.$SUF" || return $?
  done
}


function rejson () { jq --indent 2 --sort-keys --raw-output "$@"; }


function scrape_extract_init_json () {
  local INIT_RX='<script\b[^<>]*>var ytInitialPlayerResponse[^<>]+'
  local INIT_JSON="$(grep -oPe "$INIT_RX" -- "$@")"
  INIT_JSON="${INIT_JSON#*>}"
  INIT_JSON="${INIT_JSON#*=}"
  INIT_JSON="${INIT_JSON#* }"
  INIT_JSON="${INIT_JSON%\}*}}"
  <<<"$INIT_JSON" rejson .
}


function scrape_categorize_one_video () {
  local V_ID="$1"
  printf '%s\t' "https://youtu.be/$V_ID"
  scrape_download_watch_page "$V_ID" || return $?
  local GEOM=( $(
    scrape_download_watch_page "$V_ID" init.json \
      | jq '.streamingData.adaptiveFormats[0]' \
      | jq '.width, .height'
    ) )
  local W="${GEOM[0]:-0}"
  local H="${GEOM[1]:-0}"
  [ "$W" -ge 1 -a "$H" -ge 1 ] || return 3$(
    echo "E: Failed to detect size of v=$V_ID" >&2)
  printf '%s\t' "$W" "$H"
  local O='square'
  [ "$H" -gt "$W" ] && O='verti'
  [ "$W" -gt "$H" ] && O='horiz'
  echo "$O"
}










scrape_main "$@"; exit $?
