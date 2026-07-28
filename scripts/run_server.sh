#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
ENV_FILE="${ROOT_DIR}/.envs/.env.production"

PROD_PROFILE="prod"
DEV_PROFILE="dev"

BASE_SERVICES=(
  backend
  inference-server
  celery
  redis
  mongo
  mongo-express
)

ALL_SERVICES=(
  frontend
  frontend-dev
  "${BASE_SERVICES[@]}"
)

usage() {
  cat <<'EOF'
Usage: ./scripts/run_server.sh <command> [options] [service...]

Commands:
  up [service...]       Start all services (or only the listed ones)
  build [service...]    Build images and start all services (or only the listed ones)
  down                  Stop and remove all containers
  start <service>       Start one or more services
  restart <service>     Restart one or more services
  stop <service>        Stop one or more services
  logs [service]        Tail logs (all services if none specified)
  ps                    List running compose services
  dev                   Start stack with hot-reload frontend (dev profile)

Options:
  --dev                 Use the dev frontend profile instead of production

Examples:
  ./scripts/run_server.sh up
  ./scripts/run_server.sh build
  ./scripts/run_server.sh down
  ./scripts/run_server.sh start backend
  ./scripts/run_server.sh restart inference-server
  ./scripts/run_server.sh build backend inference-server
  ./scripts/run_server.sh dev
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

ensure_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    die "${ENV_FILE} not found. Copy .env.example to .envs/.env.production and configure it."
  fi
}

compose() {
  local -a args=(-f "${COMPOSE_FILE}" --env-file "${ENV_FILE}")

  if [[ -f "${ROOT_DIR}/.env" ]]; then
    args+=(--env-file "${ROOT_DIR}/.env")
  fi

  docker compose "${args[@]}" "$@"
}

profile_for_service() {
  case "$1" in
    frontend) echo "${PROD_PROFILE}" ;;
    frontend-dev) echo "${DEV_PROFILE}" ;;
    *) echo "" ;;
  esac
}

collect_profiles() {
  local -a profiles=()
  local service profile

  if [[ "${USE_DEV_PROFILE}" == "true" ]]; then
    profiles+=("${DEV_PROFILE}")
    printf '%s\n' "${profiles[@]}"
    return
  fi

  if [[ $# -eq 0 ]]; then
    profiles+=("${PROD_PROFILE}")
    printf '%s\n' "${profiles[@]}"
    return
  fi

  for service in "$@"; do
    profile="$(profile_for_service "${service}")"
    if [[ -n "${profile}" ]]; then
      local existing
      for existing in "${profiles[@]:-}"; do
        [[ "${existing}" == "${profile}" ]] && continue 2
      done
      profiles+=("${profile}")
    fi
  done

  if [[ ${#profiles[@]} -eq 0 ]]; then
    return
  fi

  printf '%s\n' "${profiles[@]}"
}

profile_args() {
  local -a args=()
  local profile

  while IFS= read -r profile; do
    [[ -z "${profile}" ]] && continue
    args+=(--profile "${profile}")
  done < <(collect_profiles "$@")

  if [[ ${#args[@]} -gt 0 ]]; then
    printf '%s\n' "${args[@]}"
  fi
}

default_services() {
  if [[ "${USE_DEV_PROFILE}" == "true" ]]; then
    printf '%s\n' frontend-dev "${BASE_SERVICES[@]}"
  else
    printf '%s\n' frontend "${BASE_SERVICES[@]}"
  fi
}

cmd_up() {
  local build=false
  local -a services=()
  local arg

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --build) build=true; shift ;;
      --dev) USE_DEV_PROFILE=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) services+=("$1"); shift ;;
    esac
  done

  local -a compose_profiles=()
  local -a targets=()

  if [[ ${#services[@]} -eq 0 ]]; then
    while IFS= read -r arg; do
      targets+=("${arg}")
    done < <(default_services)
  else
    targets=("${services[@]}")
  fi

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && compose_profiles+=("${arg}")
  done < <(profile_args "${targets[@]}")

  local -a up_args=(-d)
  [[ "${build}" == "true" ]] && up_args+=(--build)

  if [[ ${#compose_profiles[@]} -gt 0 ]]; then
    compose "${compose_profiles[@]}" up "${up_args[@]}" "${targets[@]}"
  else
    compose up "${up_args[@]}" "${targets[@]}"
  fi
}

cmd_down() {
  compose --profile "${PROD_PROFILE}" --profile "${DEV_PROFILE}" down "$@"
}

cmd_start() {
  [[ $# -eq 0 ]] && die "start requires at least one service name"

  local -a compose_profiles=()
  local arg

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && compose_profiles+=("${arg}")
  done < <(profile_args "$@")

  if [[ ${#compose_profiles[@]} -gt 0 ]]; then
    compose "${compose_profiles[@]}" up -d "$@"
  else
    compose up -d "$@"
  fi
}

cmd_restart() {
  [[ $# -eq 0 ]] && die "restart requires at least one service name"

  local -a compose_profiles=()
  local arg

  while IFS= read -r arg; do
    [[ -n "${arg}" ]] && compose_profiles+=("${arg}")
  done < <(profile_args "$@")

  if [[ ${#compose_profiles[@]} -gt 0 ]]; then
    compose "${compose_profiles[@]}" restart "$@"
  else
    compose restart "$@"
  fi
}

cmd_stop() {
  [[ $# -eq 0 ]] && die "stop requires at least one service name"
  compose stop "$@"
}

cmd_logs() {
  local -a compose_profiles=()
  local arg

  if [[ $# -gt 0 ]]; then
    while IFS= read -r arg; do
      [[ -n "${arg}" ]] && compose_profiles+=("${arg}")
    done < <(profile_args "$@")
  else
    while IFS= read -r arg; do
      [[ -n "${arg}" ]] && compose_profiles+=("${arg}")
    done < <(profile_args frontend frontend-dev)
  fi

  if [[ ${#compose_profiles[@]} -gt 0 ]]; then
    compose "${compose_profiles[@]}" logs -f "$@"
  else
    compose logs -f "$@"
  fi
}

cmd_ps() {
  compose --profile "${PROD_PROFILE}" --profile "${DEV_PROFILE}" ps
}

main() {
  local command="${1:-}"
  shift || true

  USE_DEV_PROFILE=false

  case "${command}" in
    -h|--help|help|"")
      usage
      exit 0
      ;;
  esac

  ensure_env

  case "${command}" in
    up|start)
      if [[ "${command}" == "start" && $# -eq 0 ]]; then
        cmd_up
      elif [[ "${command}" == "start" ]]; then
        cmd_start "$@"
      else
        cmd_up "$@"
      fi
      ;;
    build)
      cmd_up --build "$@"
      ;;
    down)
      cmd_down "$@"
      ;;
    restart)
      cmd_restart "$@"
      ;;
    stop)
      cmd_stop "$@"
      ;;
    logs)
      cmd_logs "$@"
      ;;
    ps|status)
      cmd_ps
      ;;
    dev)
      USE_DEV_PROFILE=true
      cmd_up "$@"
      ;;
    *)
      die "unknown command: ${command}. Run ./scripts/run_server.sh --help"
      ;;
  esac
}

main "$@"
