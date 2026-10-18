#!/usr/bin/env bash
# Verifica que los compose del repo cumplan el contrato de Coolify:
#  - servicios sin profiles no exponen puertos, ni ganan poder sobre el host
#  - no hay nombres fijos a nivel raíz ni redes/volúmenes con nombre fijo
#  - las variables obligatorias se resuelven con valores ficticios
#
# Uso: bash scripts/coolify-check.sh [base_dir] [compose ...]
# Si no se pasan compose, usa solo compose.supabase.yaml (el compose que Coolify
# publica para esta app), conforme al contrato del plan.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
base_dir="${1:-$repo_root}"
shift || true

if [ "$#" -gt 0 ]; then
  compose_files=("$@")
else
  compose_files=("$base_dir/compose.supabase.yaml")
fi

if [ "${#compose_files[@]}" -eq 0 ]; then
  echo "ERROR: no se encontraron compose files en $base_dir" >&2
  exit 2
fi

for var in docker jq python3; do
  if ! command -v "$var" >/dev/null 2>&1; then
    echo "ERROR: $var no está instalado" >&2
    exit 2
  fi
done
python3 -c 'import yaml' 2>/dev/null || {
  echo "ERROR: PyYAML no está instalado en python3" >&2
  exit 2
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail=0

for compose in "${compose_files[@]}"; do
  if [ ! -f "$compose" ]; then
    echo "ERROR: compose no existe: $compose" >&2
    fail=1
    continue
  fi

  compose_name="$(basename "$compose")"
  fail_before_compose="$fail"
  echo "==> Verificando $compose_name"

  # Generar .env con valores ficticios para cada ${VAR} del compose
  env_file="$tmp_dir/${compose_name}.env"
  : > "$env_file"

  vars_in_compose="$(grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*(:[^}]*)?\}' "$compose" \
    | sed -E 's/^\$\{([A-Za-z_][A-Za-z0-9_]*).*$/\1/' \
    | sort -u)"

  if grep -qE '\$\{(DB_SSLMODE|DB_NAME|DB_ALLOW_INTERNAL_HOST)\b' "$compose"; then
    echo 'DB_SSLMODE=disable' >> "$env_file"
    echo 'DB_NAME=mvp_prueba' >> "$env_file"
  fi

  for var_name in $vars_in_compose; do
    if grep -qE "^${var_name}=" "$env_file"; then
      continue
    fi
    case "$var_name" in
      *_URL|*_ORIGIN|*_ENDPOINT|*_HOST|*_DSN)
        echo "${var_name}=https://ejemplo.invalid" >> "$env_file"
        ;;
      *)
        echo "${var_name}=x1234567890abcdef" >> "$env_file"
        ;;
    esac
  done

  echo "--- env generado ---"
  sed 's/^/    /' "$env_file"
  echo "--------------------"

  # Renderizar el compose
  rendered="$tmp_dir/${compose_name}.json"
  if ! docker compose --project-directory "$base_dir" -f "$compose" \
      --env-file "$env_file" config --format json > "$rendered" 2>"$tmp_dir/${compose_name}.err"; then
    echo "ERROR: docker compose config falló en $compose_name" >&2
    sed 's/^/    /' "$tmp_dir/${compose_name}.err" >&2
    fail=1
    continue
  fi

  # Punto 2 sobre YAML original: name fijo a nivel raíz, redes y volúmenes con
  # name fijo. Docker añade automáticamente el `name` raíz al renderizar; lo que
  # prohíbe el contrato es forzarlo en el YAML.
  yaml_summary="$(python3 - "$compose" <<'PY'
import sys, yaml
with open(sys.argv[1]) as fh:
    data = yaml.safe_load(fh) or {}
root_name = data.get("name")
nets_with_name = [k for k, v in (data.get("networks") or {}).items()
                  if isinstance(v, dict) and v.get("name")]
vols_with_name = [k for k, v in (data.get("volumes") or {}).items()
                  if isinstance(v, dict) and v.get("name")]
print(f"ROOT={root_name or ''}")
print(f"NETS={','.join(nets_with_name)}")
print(f"VOLS={','.join(vols_with_name)}")
PY
  )"
  root_name="$(echo "$yaml_summary" | sed -n 's/^ROOT=//p')"
  bad_net_names="$(echo "$yaml_summary" | sed -n 's/^NETS=//p')"
  bad_vol_names="$(echo "$yaml_summary" | sed -n 's/^VOLS=//p')"

  if [ -n "$root_name" ]; then
    echo "  FALLA $compose_name: name fijo a nivel raíz ($root_name)" >&2
    fail=1
  fi
  if [ -n "$bad_net_names" ]; then
    echo "  FALLA $compose_name: redes con name fijo ($bad_net_names)" >&2
    fail=1
  fi
  if [ -n "$bad_vol_names" ]; then
    echo "  FALLA $compose_name: volúmenes con name fijo ($bad_vol_names)" >&2
    fail=1
  fi

  # Punto 1: servicios sin profiles no exponen puertos ni ganan poder sobre
  # el host. Revisión sobre el render (donde se materializan profiles).
  check_service() {
    local svc_name="$1"
    local body="$2"

    local profiles
    profiles="$(echo "$body" | jq -r '.profiles // [] | join(",")')"
    if [ -n "$profiles" ]; then
      return 0
    fi

    local bad
    bad="$(echo "$body" | jq -r '
      [
        (has("ports") | select(.) | "ports"),
        (has("container_name") | select(.) | "container_name"),
        (has("privileged") | select(.) | "privileged"),
        (has("cap_add") | select(.) | "cap_add"),
        (has("devices") | select(.) | "devices"),
        ((.network_mode // "") | select(. == "host") | "network_mode=host"),
        ((.pid // "") | select(. == "host") | "pid=host"),
        ((.ipc // "") | select(. == "host") | "ipc=host"),
        ((.security_opt // []) | map(select(test("unconfined"))) | select(. != []) | "security_opt=unconfined")
      ] | map(select(. != null)) | join(",")
    ')"
    if [ -n "$bad" ]; then
      echo "  FALLA $svc_name: $bad (punto 1)" >&2
      fail=1
    fi

    local repo_real
    repo_real="$(cd "$repo_root" && pwd)"
    local bad_binds
    bad_binds="$(echo "$body" | jq -r --arg repo "$repo_real" '
      (.volumes // []) as $vols
      | $vols
      | map(
          if type == "object" then
            (if (.source // "") == "/var/run/docker.sock"
                then "docker.sock"
                elif (((.source // "") | test("^/")) and (((.source // "") | startswith($repo)) | not))
                then "fuera del repo: " + .source
                else empty
                end)
          else empty
          end
        )
      | join("|")
    ')"
    if [ -n "$bad_binds" ]; then
      echo "  FALLA $svc_name: bind prohibido ($bad_binds)" >&2
      fail=1
    fi
  }

  svc_names="$(jq -r '.services | keys[]' "$rendered")"
  while IFS= read -r svc_name; do
    [ -z "$svc_name" ] && continue
    svc_body="$(jq -c ".services.\"$svc_name\"" "$rendered")"
    check_service "$svc_name" "$svc_body"
  done <<< "$svc_names"

  # supabase-pg: DB_NAME=mvp_prueba y DB_SSLMODE=disable en el render.
  if grep -qE '\$\{(DB_NAME|DB_SSLMODE)\b' "$compose"; then
    rendered_text="$(cat "$rendered")"
    if ! echo "$rendered_text" | grep -q 'mvp_prueba'; then
      echo "  FALLA $compose_name: DB_NAME=mvp_prueba no aparece en el render" >&2
      fail=1
    fi
    if ! echo "$rendered_text" | grep -q '"disable"'; then
      echo "  FALLA $compose_name: DB_SSLMODE=disable no aparece en el render" >&2
      fail=1
    fi
  fi

  if [ "$fail" -eq "$fail_before_compose" ]; then
    echo "    OK"
  else
    echo "    FALLA $compose_name (ver líneas anteriores)"
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "RESULTADO: PASS"
  exit 0
fi
echo "RESULTADO: FAIL"
exit 1