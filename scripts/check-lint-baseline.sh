#!/usr/bin/env bash
# 校验五个 app 的 ruff 规则基线逐字一致。
#
# 2026-10-18 把五个仓库的 [tool.ruff.lint] 统一成同一套 select / ignore
# （见 docs/project/project-governance/004-known-deviations.md 第 6 条）。
# 统一本身只是一次性动作，难的是不退化：谁在某个仓库顺手加一条 ignore 把 CI 弄绿，
# 统一就散了。这个脚本就是那道闸。
#
# 允许按仓库不同的只有三项，这里不管：
#   target-version   —— 必须与各自 requires-python 下界一致
#   per-file-ignores —— 按文件收窄，本来就是仓库局部的事
#   extend-select    —— 在基线之上自愿加严，不影响基线本身
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 基线以核心库为准：它是 app 清单里的第一个，也是规则最先定下来的地方。
readonly REFERENCE="apps/fundrive"

# 从 setup.sh 的登记表里取路径，避免这里再抄一份 app 清单。
mapfile -t PATHS < <(
  sed -n '/^readonly -a APP_REGISTRY=(/,/^)/p' scripts/setup.sh |
    grep -oE '"[^"]+"' | tr -d '"' | cut -d'|' -f2
)
[[ ${#PATHS[@]} -gt 0 ]] || { printf 'FAIL 没能从 scripts/setup.sh 解析出 app 路径\n' >&2; exit 1; }

# 打印某个 pyproject 的 select + ignore，规范化成可比较的形式。
dump_baseline() {
  python3 - "$1" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as fh:
    lint = tomllib.load(fh).get("tool", {}).get("ruff", {}).get("lint", {})
print("select=" + ",".join(sorted(lint.get("select", []))))
print("ignore=" + ",".join(sorted(lint.get("ignore", []))))
PY
}

missing=0
for path in "${PATHS[@]}"; do
  [[ -f "${path}/pyproject.toml" ]] || {
    printf 'skip %s 未检出，跳过\n' "${path}"
    missing=$((missing + 1))
  }
done
[[ ${missing} -eq 0 ]] || {
  printf 'FAIL 有子模块未检出，先执行 bash scripts/init.sh\n' >&2
  exit 1
}

expected="$(dump_baseline "${REFERENCE}/pyproject.toml")"
printf '基线（以 %s 为准）：\n%s\n\n' "${REFERENCE}" "${expected}"

fail_count=0
for path in "${PATHS[@]}"; do
  actual="$(dump_baseline "${path}/pyproject.toml")"
  if [[ "${actual}" == "${expected}" ]]; then
    printf 'ok   %s\n' "${path}"
  else
    printf 'FAIL %s 的规则基线与 %s 不一致：\n' "${path}" "${REFERENCE}" >&2
    diff <(printf '%s\n' "${expected}") <(printf '%s\n' "${actual}") |
      sed 's/^/       /' >&2 || true
    fail_count=$((fail_count + 1))
  fi
done

printf '\n'
if [[ ${fail_count} -gt 0 ]]; then
  printf '%d 个仓库的 ruff 基线不一致。要改基线就五个一起改 —— 理由写进\n' "${fail_count}" >&2
  printf 'docs/project/project-governance/004-known-deviations.md 第 6 条。\n' >&2
  exit 1
fi
printf '五个仓库的 ruff 规则基线一致。\n'
