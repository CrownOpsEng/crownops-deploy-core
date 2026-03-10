#!/usr/bin/env bash

umask 077

create_smoke_tmpdir() {
  local root_dir="$1"
  local base_tmp="${TMPDIR:-${root_dir}/.tmp}"
  local temp_dir

  mkdir -p "${base_tmp}"
  temp_dir="$(mktemp -d -p "${base_tmp}" smoke.XXXXXX)"
  chmod 700 "${temp_dir}"
  printf '%s\n' "${temp_dir}"
}
