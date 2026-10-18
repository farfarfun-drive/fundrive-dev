#!/usr/bin/env bash
# Markdown 相对链接检查。
#
# 只查本仓库受版本控制的 .md 文件里的**相对**链接（http/https/mailto 和纯锚点跳过）。
# 起因：fundrive 仓库里有个指向 ../../DEVELOPMENT_GUIDE.md 的链接，那个路径从来不存在，
# 一直没人发现 —— 文档断链没有编译器会报，只能靠这种检查。
#
# 不查的东西（说清楚边界，免得有人以为它管得更多）：
#   - 外链是否 200：要联网、会因为别人的站点挂掉而让 CI 变红
#   - 锚点（#section）是否存在：中文标题的 GitHub 锚点规则不稳定，误报率太高
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail_count=0
checked=0

# git ls-files 不会列出子模块内部的文件，所以天然只覆盖本仓库自己的文档。
while read -r file; do
  dir="$(dirname "${file}")"
  # 提取 ](target) 里的 target；排除 http(s)://、mailto:、以 # 开头的纯锚点
  while read -r link; do
    [[ -n "${link}" ]] || continue
    # 去掉链接里的锚点部分再解析路径
    path="${link%%#*}"
    # 纯锚点链接（#foo）去掉锚点后为空，跳过
    [[ -n "${path}" ]] || continue
    checked=$((checked + 1))
    if [[ ! -e "${dir}/${path}" ]]; then
      printf 'FAIL %s → %s\n' "${file}" "${link}" >&2
      fail_count=$((fail_count + 1))
    fi
  done < <(
    grep -ohE '\]\([^)]+\)' "${file}" 2>/dev/null |
      sed 's/^](//; s/)$//' |
      grep -vE '^(https?://|mailto:)' || true
  )
done < <(git ls-files '*.md')

printf '检查了 %d 个相对链接。\n' "${checked}"
if [[ ${fail_count} -gt 0 ]]; then
  printf '%d 条断链。\n' "${fail_count}" >&2
  exit 1
fi
printf '无断链。\n'
