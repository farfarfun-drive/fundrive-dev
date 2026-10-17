#!/usr/bin/env bash
# app 登记表一致性校验。
#
# scripts/setup.sh 的 APP_REGISTRY 是 app 清单的唯一来源；README.md 与 docs/ 里的表格
# 是给人读的手写副本。文档说过「两处不一致是缺陷，不是见解问题」—— 这个脚本就是判这个
# 缺陷的那把尺子，CI 会跑它。
#
# 校验项：
#   1. 登记表自身格式（四字段、类别合法、别名/路径/包名不重复）
#   2. 每个路径在 .gitmodules 里确实登记成了子模块
#   3. 子模块已检出时，pyproject.toml 的 name 与登记的 PyPI 包名一致
#   4. README.md 与两篇 docs 的应用表格行与登记表一一对应（不多不少）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

readonly SETUP="scripts/setup.sh"
# 手写副本所在的文件 —— 新增一处抄写就往这里加一行。
readonly -a TABLE_FILES=(
  "README.md"
  "docs/project/project-governance/001-overview.md"
  "docs/project/project-governance/003-release-and-entrypoint.md"
)

fail_count=0
fail() {
  printf 'FAIL %s\n' "$*" >&2
  fail_count=$((fail_count + 1))
}
ok() { printf 'ok   %s\n' "$*"; }

# 从 setup.sh 里抽出登记表，避免再开一个会和它漂移的数据文件。
mapfile -t REGISTRY < <(
  sed -n '/^readonly -a APP_REGISTRY=(/,/^)/p' "${SETUP}" |
    grep -oE '"[^"]+"' | tr -d '"'
)
[[ ${#REGISTRY[@]} -gt 0 ]] ||
  { printf 'FAIL 没能从 %s 解析出 APP_REGISTRY\n' "${SETUP}" >&2; exit 1; }
printf '从 %s 解析到 %d 个 app\n\n' "${SETUP}" "${#REGISTRY[@]}"

# ---- 1. 登记表格式 ----------------------------------------------------------
declare -A seen_alias=() seen_path=() seen_package=()
declare -a ALIASES=() PATHS=() PACKAGES=() CLASSES=()
for entry in "${REGISTRY[@]}"; do
  IFS='|' read -r -a parts <<<"${entry}"
  if [[ ${#parts[@]} -ne 4 ]]; then
    fail "登记项字段数不是 4：${entry}"
    continue
  fi
  alias="${parts[0]}" path="${parts[1]}" package="${parts[2]}" class="${parts[3]}"
  [[ "${class}" == "service" || "${class}" == "package" ]] ||
    fail "类别只能是 service 或 package，${alias} 写的是：${class}"
  [[ -z "${seen_alias[${alias}]:-}" ]] || fail "别名重复：${alias}"
  [[ -z "${seen_path[${path}]:-}" ]] || fail "路径重复：${path}"
  [[ -z "${seen_package[${package}]:-}" ]] || fail "包名重复：${package}"
  seen_alias[${alias}]=1 seen_path[${path}]=1 seen_package[${package}]=1
  ALIASES+=("${alias}") PATHS+=("${path}") PACKAGES+=("${package}") CLASSES+=("${class}")
done
[[ ${fail_count} -eq 0 ]] && ok "登记表格式"

# ---- 2. .gitmodules ---------------------------------------------------------
for i in "${!PATHS[@]}"; do
  git config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
    grep -qx "submodule.${PATHS[$i]}.path ${PATHS[$i]}" ||
    fail ".gitmodules 里没有登记子模块：${PATHS[$i]}"
done
# 反向：.gitmodules 里有、登记表里没有的子模块
while read -r _ sub_path; do
  [[ -n "${seen_path[${sub_path}]:-}" ]] ||
    fail ".gitmodules 里的 ${sub_path} 不在 APP_REGISTRY 里"
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$')
ok ".gitmodules 与登记表双向一致"

# ---- 3. pyproject 包名 ------------------------------------------------------
for i in "${!PATHS[@]}"; do
  pyproject="${PATHS[$i]}/pyproject.toml"
  if [[ ! -f "${pyproject}" ]]; then
    printf 'skip %s 未检出，跳过包名校验\n' "${PATHS[$i]}"
    continue
  fi
  actual="$(sed -n 's/^name *= *"\([^"]*\)".*/\1/p' "${pyproject}" | head -1)"
  [[ "${actual}" == "${PACKAGES[$i]}" ]] ||
    fail "${pyproject} 的 name=${actual}，登记表写的是 ${PACKAGES[$i]}"
done
ok "pyproject 包名与登记表一致"

# ---- 4. 文档表格 ------------------------------------------------------------
# 表格行的判定：以 | 开头且含 `apps/` 的 markdown 行。
for file in "${TABLE_FILES[@]}"; do
  [[ -f "${file}" ]] || { fail "文件不存在：${file}"; continue; }
  mapfile -t rows < <(grep -nE '^\|.*`apps/' "${file}" || true)
  if [[ ${#rows[@]} -ne ${#ALIASES[@]} ]]; then
    fail "${file} 的应用表格有 ${#rows[@]} 行，登记表有 ${#ALIASES[@]} 个 app"
  fi
  for i in "${!ALIASES[@]}"; do
    matched=0
    for row in "${rows[@]}"; do
      [[ "${row}" == *'`'"${ALIASES[$i]}"'`'* ]] || continue
      [[ "${row}" == *'`'"${PATHS[$i]}"'`'* ]] || continue
      [[ "${row}" == *"${CLASSES[$i]}"* ]] || continue
      matched=$((matched + 1))
    done
    [[ ${matched} -eq 1 ]] ||
      fail "${file} 里匹配 ${ALIASES[$i]}（${PATHS[$i]}, ${CLASSES[$i]}）的表格行有 ${matched} 条，应为 1 条"
  done
  [[ ${fail_count} -eq 0 ]] && ok "${file} 应用表格"
done

printf '\n'
if [[ ${fail_count} -gt 0 ]]; then
  printf '%d 项不一致。修到一致为止 —— 唯一来源是 %s 的 APP_REGISTRY。\n' \
    "${fail_count}" "${SETUP}" >&2
  exit 1
fi
printf '全部一致。\n'
