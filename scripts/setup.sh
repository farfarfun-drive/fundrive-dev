#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# ---------------------------------------------------------------------------
# app 登记表 —— 本工作区 app 清单的唯一来源。
#
# 字段：别名|子模块路径|PyPI 包名|类别
# 类别只有两个有效值：service（有东西把它当长驻进程启动）、package（只被 import /
# pip install 成依赖）。分类在这里显式登记，不从仓库名后缀推断。
#
# 新增或删除 app 只改这一处 —— 可选 target、`all` 的展开、usage 文本全部由它派生。
# README.md 与 docs/ 里的表格仍是手写的，由 scripts/check-apps.sh 跟这张表比对
# （CI 会跑），不一致就失败。
# ---------------------------------------------------------------------------
readonly -a APP_REGISTRY=(
  "core|apps/fundrive|fundrive|package"
  "alipan|apps/fundrive-alipan|fundrive-alipan|package"
  "baidu|apps/fundrive-baidu|fundrive-baidu|package"
  "lanzou|apps/fundrive-lanzou|fundrive-lanzou|package"
  "quark|apps/fundrive-quark|fundrive-quark|package"
)

readonly -a SERVICE_ACTIONS=(start stop restart run status)
readonly -a RELEASE_ACTIONS=(install-dev install-prod upgrade rollback)
readonly -a ACTIONS=("${SERVICE_ACTIONS[@]}" "${RELEASE_ACTIONS[@]}")
# 接受版本号位置参数的 action。install-dev 与 service action 一律不接受 ——
# 多传就报错，不静默忽略。
readonly -a VERSIONED_ACTIONS=(install-prod upgrade rollback)

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

# ---- 登记表读取 -------------------------------------------------------------

app_aliases() {
  local entry
  for entry in "${APP_REGISTRY[@]}"; do
    printf '%s\n' "${entry%%|*}"
  done
}

# app_field <别名> <path|package|class>
app_field() {
  local want="$1" field="$2" entry alias path package class
  for entry in "${APP_REGISTRY[@]}"; do
    IFS='|' read -r alias path package class <<<"${entry}"
    [[ "${alias}" == "${want}" ]] || continue
    case "${field}" in
      path) printf '%s\n' "${path}" ;;
      package) printf '%s\n' "${package}" ;;
      class) printf '%s\n' "${class}" ;;
      *) die "app_field: 未知字段 ${field}" ;;
    esac
    return 0
  done
  return 1
}

apps_of_class() {
  local want="$1" entry alias path package class
  for entry in "${APP_REGISTRY[@]}"; do
    IFS='|' read -r alias path package class <<<"${entry}"
    [[ "${class}" == "${want}" ]] && printf '%s\n' "${alias}"
  done
  return 0
}

mapfile -t ALL_APPS < <(app_aliases)
mapfile -t SERVICE_APPS < <(apps_of_class service)
# release action 对 service app 与 package app 一视同仁，所以它的 all 就是全部 app。
readonly -a RELEASE_APPS=("${ALL_APPS[@]}")
readonly -a TARGETS=("${ALL_APPS[@]}" all)
TARGET_LIST="$(
  IFS='|'
  printf '%s' "${ALL_APPS[*]}"
)"
readonly TARGET_LIST

usage() {
  printf 'Usage: %s install-dev <%s|all>\n' "${0##*/}" "${TARGET_LIST}" >&2
  printf '       %s <install-prod|upgrade> <%s|all> [version]\n' "${0##*/}" "${TARGET_LIST}" >&2
  printf '       %s rollback <%s|all> <version>\n' "${0##*/}" "${TARGET_LIST}" >&2
  printf '\n' >&2
  printf 'release actions (%s) 适用于 service + package app：%s\n' \
    "$(IFS=' '; printf '%s' "${RELEASE_ACTIONS[*]}")" \
    "$(IFS=' '; printf '%s' "${RELEASE_APPS[*]}")" >&2
  if [[ ${#SERVICE_APPS[@]} -gt 0 ]]; then
    printf 'service actions (%s) 只适用于 service app：%s\n' \
      "$(IFS=' '; printf '%s' "${SERVICE_ACTIONS[*]}")" \
      "$(IFS=' '; printf '%s' "${SERVICE_APPS[*]}")" >&2
  else
    printf 'service actions (%s) 只适用于 service app —— 本工作区暂无 service app，这几个 action 目前无可用目标\n' \
      "$(IFS=' '; printf '%s' "${SERVICE_ACTIONS[*]}")" >&2
  fi
  printf 'build/publish 不是本脚本的 action —— 由仓库根的 funbuild build（scripts/build.sh）统一 fan out。\n' >&2
}

choose() {
  command -v gum >/dev/null 2>&1 ||
    die "缺少参数且没有安装 gum，请把参数写全后重试"
  gum choose "$@"
}

is_service_action() {
  contains "$1" "${SERVICE_ACTIONS[@]}"
}

# ---- release action：由本仓库直接执行 ---------------------------------------
#
# 五个 app 都是没有 CLI、没有进程的纯库，装一个包就是一条 uv 命令。让每个 app 仓库
# 再背一个只包着 uv 的 scripts/setup.sh 是纯仪式，所以 release action 在这里实现，
# 不转发。service action 仍然转发给 app 自己的生命周期脚本（见 do_service）。
# 取舍留档：docs/project/project-governance/004-known-deviations.md 第 1 条。

# uv pip install 必须有明确的目标环境。没有激活的 venv、仓库根也没有 .venv 时，
# 要求显式 FUNDRIVE_INSTALL_SYSTEM=1，而不是默默装进系统 python。
resolve_uv_target() {
  command -v uv >/dev/null 2>&1 ||
    die "release action 需要 uv，请先安装：https://docs.astral.sh/uv/"
  UV_TARGET=()
  if [[ -n "${VIRTUAL_ENV:-}" || -d "${ROOT}/.venv" ]]; then
    return 0
  fi
  if [[ "${FUNDRIVE_INSTALL_SYSTEM:-0}" == "1" ]]; then
    UV_TARGET=(--system)
    return 0
  fi
  die "没有找到目标环境：先激活一个 venv（或在仓库根 uv venv），或显式设置 FUNDRIVE_INSTALL_SYSTEM=1 装进当前 python"
}

do_release() {
  local action="$1" app="$2" version="${3:-}" path package
  path="$(app_field "${app}" path)"
  package="$(app_field "${app}" package)"

  local -a cmd=(uv pip install "${UV_TARGET[@]+${UV_TARGET[@]}}")
  case "${action}" in
    install-dev)
      # 从工作树可编辑安装，覆盖索引上的发布版 —— 要求子模块已检出。
      # 注意判断的是 ${path}/.git：git 会为未初始化的子模块留一个空挂载点目录，
      # 所以 -d "${path}" 恒为真，检查不出「plain clone 后没跑 init.sh」。
      [[ -e "${path}/.git" ]] ||
        die "子模块未检出：${path}，先执行 bash scripts/init.sh"
      cmd+=(--editable "${path}")
      ;;
    install-prod)
      cmd+=("${package}${version:+==${version}}")
      ;;
    upgrade)
      if [[ -n "${version}" ]]; then
        cmd+=("${package}==${version}")
      else
        cmd+=(--upgrade "${package}")
      fi
      ;;
    rollback)
      cmd+=("${package}==${version}")
      ;;
    *)
      die "do_release: 未知 action ${action}"
      ;;
  esac

  printf '== %s: %s ==\n' "${app}" "${action}"
  printf '+ %s\n' "${cmd[*]}"
  "${cmd[@]}"
}

# ---- service action：转发给 app 自己的生命周期脚本 ---------------------------
#
# 进程的起停只有 app 自己知道怎么做，本仓库不重新实现。本工作区目前没有 service app，
# 这个函数要等将来登记了 service 类 app 才会被走到。
do_service() {
  local action="$1" app="$2" path
  path="$(app_field "${app}" path)"
  [[ -e "${path}/.git" ]] ||
    die "子模块未检出：${path}，先执行 bash scripts/init.sh"
  [[ -x "${path}/scripts/setup.sh" ]] ||
    die "${path} 还没有可执行的 scripts/setup.sh，无法分发 ${action}（见 docs/project/project-governance/003-release-and-entrypoint.md）"
  printf '== %s: %s ==\n' "${app}" "${action}"
  (cd "${path}" && ./scripts/setup.sh "${action}")
}

# 多 app 时按登记表的声明顺序依次处理；set -e 下第一个失败即中止，
# 不继续处理后面的 app。
dispatch() {
  local action="$1" target="$2" version="${3:-}" app
  local -a apps
  if [[ "${target}" == "all" ]]; then
    if is_service_action "${action}"; then
      apps=("${SERVICE_APPS[@]+${SERVICE_APPS[@]}}")
    else
      apps=("${RELEASE_APPS[@]}")
    fi
  else
    apps=("${target}")
  fi

  for app in "${apps[@]}"; do
    if is_service_action "${action}"; then
      [[ "$(app_field "${app}" class)" == "service" ]] ||
        die "${action} 只适用于 service app，不适用于：${app}"
      do_service "${action}" "${app}"
    else
      do_release "${action}" "${app}" "${version}"
    fi
  done
}

main() {
  [[ $# -le 3 ]] || {
    usage
    die "参数过多：最多 <action> <target> [version]，收到 $# 个"
  }

  local action="${1:-}"
  local target="${2:-}"
  local version="${3:-}"

  [[ -n "${action}" ]] || action="$(choose "${ACTIONS[@]}")"
  contains "${action}" "${ACTIONS[@]}" || {
    usage
    die "unknown action: ${action}"
  }

  # service action 在没有任何 service app 时直接报错，不弹一个全是死选项的菜单。
  if is_service_action "${action}" && [[ ${#SERVICE_APPS[@]} -eq 0 ]]; then
    die "${action} 只适用于 service app，本工作区目前没有 service app"
  fi

  [[ -n "${version}" ]] || [[ "${action}" != "rollback" ]] ||
    die "rollback 必须显式给出版本号：${0##*/} rollback <${TARGET_LIST}|all> <version>"
  [[ -z "${version}" ]] || contains "${action}" "${VERSIONED_ACTIONS[@]}" || {
    usage
    die "${action} 不接受版本号参数，收到：${version}"
  }

  [[ -n "${target}" ]] || target="$(choose "${TARGETS[@]}")"
  contains "${target}" "${TARGETS[@]}" || {
    usage
    die "unknown target: ${target}"
  }

  is_service_action "${action}" || resolve_uv_target
  dispatch "${action}" "${target}" "${version}"
}

main "$@"
