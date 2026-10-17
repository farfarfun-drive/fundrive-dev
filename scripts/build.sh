#!/usr/bin/env bash
# 构建发布的唯一入口。funbuild 认 apps/ + scripts/funbuild.toml 这个布局，自己 fan out
# 到每个子模块并统一 push 一次，本脚本不重复实现它的任何一步。
#
# 参数原样转发给 funbuild build：
#   bash scripts/build.sh                      # 自动递增共享版本号，commit 信息自动生成
#   bash scripts/build.sh "fix: ..."           # 指定 commit 信息
#   bash scripts/build.sh --version 2.1.0      # 指定发布版本号（只能单调前进）
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v funbuild >/dev/null 2>&1 || {
  printf 'error: 需要 funbuild，先安装：uv tool install funbuild（或 pip install funbuild）\n' >&2
  exit 2
}

exec funbuild build "$@"
