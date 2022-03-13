#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function groupify () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?
  local ORIG='all.tsv'
  local GRPS=( $(grep -vPe '^#' -- "$ORIG" | grep -oPe '\t\w+$' | sort -u) )
  local GRP=""
  for GRP in "${GRPS[@]}"; do
    echo "=== $GRP ==="
    grep -Pe '^#|\t'"$GRP"'$' -- "$ORIG" | tee -- "$GRP".tsv
  done
}

groupify "$@"; exit $?
