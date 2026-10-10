#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

readonly -a SERVICE_ACTIONS=(start stop restart run status)
readonly -a RELEASE_ACTIONS=(install-dev install-prod upgrade rollback)
readonly -a ACTIONS=("${SERVICE_ACTIONS[@]}" "${RELEASE_ACTIONS[@]}")
readonly -a TARGETS=(core alipan baidu lanzou quark all)

# all 的含义按 action 分组而定：service action 只覆盖 service app，
# release action 覆盖 service + package app。
# 本工作区目前没有 service app —— 五个 app 全是只被 import / pip install 的库，
# 没有任何东西把它们当长驻进程启动。ALL_SERVICE_APPS 因此是空的，
# `start all` 之类的调用会报错退出，而不是静默什么都不做。
readonly -a ALL_SERVICE_APPS=()
readonly -a ALL_RELEASE_APPS=(core alipan baidu lanzou quark)

usage() {
  printf 'Usage: %s install-dev <core|alipan|baidu|lanzou|quark|all>\n' "${0##*/}" >&2
  printf '       %s <install-prod|upgrade> <core|alipan|baidu|lanzou|quark|all> [version]\n' "${0##*/}" >&2
  printf '       %s rollback <core|alipan|baidu|lanzou|quark|all> <version>\n' "${0##*/}" >&2
  printf '\n' >&2
  printf 'release actions (install-dev/install-prod/upgrade/rollback) 适用于 service + package app：core alipan baidu lanzou quark\n' >&2
  printf 'service actions (start/stop/restart/run/status) 只适用于 service app —— 本工作区暂无 service app，这几个 action 目前无可用目标\n' >&2
  printf 'build/publish 不是本脚本的 action —— 由仓库根的 `funbuild build`（scripts/build.sh）统一 fan out。\n' >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

choose() {
  command -v gum >/dev/null 2>&1 ||
    die "缺少参数且没有安装 gum，请把参数写全后重试"
  gum choose "$@"
}

# Service app：有东西把它当长驻进程启动并与之通信。只有这些接受 service action。
# 分类是在这里显式登记的，不从仓库名后缀推断 —— 本工作区目前一个都没有。
# 将来 fundrive 长出 fundrive-api / fundrive-web 这类带进程的 app 时，
# 在这里登记别名，并同步更新 ALL_SERVICE_APPS、TARGETS、usage 与 README 应用表格。
resolve_service_app() {
  case "$1" in
    *) return 1 ;;
  esac
}

# Package app：只会被 import / pip install 成依赖，没有任何东西把它当进程启动。
# core 是统一网盘接口的核心库；其余四个是各网盘的驱动实现，独立发布给第三方使用。
resolve_package_app() {
  case "$1" in
    core) printf '%s\n' "apps/fundrive" ;;
    alipan) printf '%s\n' "apps/fundrive-alipan" ;;
    baidu) printf '%s\n' "apps/fundrive-baidu" ;;
    lanzou) printf '%s\n' "apps/fundrive-lanzou" ;;
    quark) printf '%s\n' "apps/fundrive-quark" ;;
    *) return 1 ;;
  esac
}

# Release action 对 service app 与 package app 一视同仁。
# nested workspace app 两者都不解析 —— 本工作区目前没有这类 app。
resolve_release_app() {
  resolve_service_app "$1" 2>/dev/null || resolve_package_app "$1" 2>/dev/null
}

is_service_action() {
  contains "$1" "${SERVICE_ACTIONS[@]}"
}

# 多 app 时按 ALL_* 数组的声明顺序依次处理；set -e 下第一个失败即中止，
# 不继续处理后面的 app。
dispatch_app_action() {
  local action="$1" target="$2" version="${3:-}" app path
  local -a apps
  if [[ "${target}" == "all" ]]; then
    if is_service_action "${action}"; then
      apps=("${ALL_SERVICE_APPS[@]+${ALL_SERVICE_APPS[@]}}")
      [[ ${#apps[@]} -gt 0 ]] ||
        die "${action} 只适用于 service app，本工作区目前没有 service app"
    else
      apps=("${ALL_RELEASE_APPS[@]}")
    fi
  else
    apps=("${target}")
  fi
  for app in "${apps[@]}"; do
    if is_service_action "${action}"; then
      path="$(resolve_service_app "${app}")" ||
        die "${action} 只适用于 service app，不适用于：${app}"
    else
      path="$(resolve_release_app "${app}")" || die "${action} 不适用于：${app}"
    fi
    # 子模块没检出（plain clone 后没跑 init.sh）或该 app 还没有自己的
    # scripts/setup.sh 时，直接说清楚缺什么，而不是扔一个 "No such file"。
    [[ -d "${path}" ]] || die "子模块未检出：${path}，先执行 bash scripts/init.sh"
    [[ -x "${path}/scripts/setup.sh" ]] ||
      die "${path} 还没有可执行的 scripts/setup.sh，无法分发 ${action}（见 docs/project/project-governance/003-release-and-entrypoint.md）"
    printf '== %s: %s ==\n' "${app}" "${action}"
    (cd "${path}" && ./scripts/setup.sh "${action}" ${version:+"${version}"})
  done
}

main() {
  local action="${1:-}"
  local target="${2:-}"
  local version="${3:-}"

  [[ -n "${action}" ]] || action="$(choose "${ACTIONS[@]}")"
  contains "${action}" "${ACTIONS[@]}" || {
    usage
    die "unknown action: ${action}"
  }

  [[ -n "${target}" ]] || target="$(choose "${TARGETS[@]}")"

  case "${action}" in
    rollback)
      [[ -n "${version}" ]] ||
        die "rollback 必须显式给出版本号：${0##*/} rollback <core|alipan|baidu|lanzou|quark|all> <version>"
      contains "${target}" "${TARGETS[@]}" || {
        usage
        die "unknown target: ${target}"
      }
      dispatch_app_action "${action}" "${target}" "${version}"
      ;;
    *)
      contains "${target}" "${TARGETS[@]}" || {
        usage
        die "unknown target: ${target}"
      }
      dispatch_app_action "${action}" "${target}" "${version}"
      ;;
  esac
}

main "$@"
