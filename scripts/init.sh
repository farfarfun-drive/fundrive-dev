#!/usr/bin/env bash
# plain clone（没带 --recurse-submodules）之后唯一要跑的命令：把子模块检出齐。
# 不需要参数、不交互。
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git submodule update --init --recursive
