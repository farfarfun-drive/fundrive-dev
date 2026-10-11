# 本地开发

本章只写跨仓库的部分：怎么把五个子模块检出齐、改动落在哪个仓库、按什么顺序提交。
单个 app 的安装、配置与用法见各自仓库的 `README.md`。

## 检出

首次克隆时连带子模块：

```bash
git clone --recurse-submodules https://github.com/farfarfun-drive/fundrive-dev.git
cd fundrive-dev
```

已经是 plain clone（没带 `--recurse-submodules`）时：

```bash
bash scripts/init.sh      # git submodule init && git submodule update
```

`scripts/init.sh` 不需要任何参数、不交互，这是新同学在 plain clone 之后唯一要跑的命令。

## 跨仓库改动的提交顺序

子模块指针和 app 仓库的 commit 是**两个仓库里的两个 commit**，谁都不能单独动：

1. 在 `apps/<name>` 里改代码、commit，**先 push 到该 app 自己的 remote**。
2. 回到本仓库根，`git add apps/<name>` 把移动后的指针入栈（多个 app 一起改就一起 add），
   然后 commit + push 本仓库。
3. 多个 app 为一次协调发布一起变更时，把它们的指针 bump 合并成**一个** dev 仓库 commit，
   而不是每个 app 一个 commit —— 这样历史读起来是「这一版指向这些 commit」，
   而不是一串互不相关的单 app bump。

两条禁止项：

- **不要**让 app 仓库有已 push 的 commit、而本仓库的指针更新从没提交 —— 那会让
  「dev 仓库说什么版本一起发的」和现实静默脱节。
- **不要**改 `apps/<name>` 里的文件却只在 dev 仓库层面 commit —— 子模块工作树的改动必须
  commit 在 app 仓库自己里，dev 仓库只能记录「我指向哪个 app commit」。

动手之前先 `git submodule status` 确认没有意外的 `+`（指针超前于已提交内容）或
`-`（子模块没检出）标记。

## 拉取全部子模块最新

```bash
git submodule update --remote
git add apps/fundrive apps/fundrive-alipan apps/fundrive-baidu apps/fundrive-lanzou apps/fundrive-quark
```

`--remote` 之后子模块通常处于 detached HEAD；`funbuild build` 会在构建前自己切回远端默认
分支（只在确实 detached 时切，不打断手动切到的 feature 分支）。手工开发时如果要在子模块里
提交，先自己 `git -C apps/<name> switch master`。

## 本地安装与验证

五个 app 都是 uv 管理的 Python 包（`pyproject.toml` + `uv.lock`），在各自目录里操作：

```bash
cd apps/fundrive
uv sync                                  # 装依赖（含 dev 组）
uv sync --extra baidu --extra lanzou     # 需要某个网盘驱动时按 extra 装
uv run pytest
```

核心库与驱动联调时，让 `fundrive` 用工作树里的驱动而不是索引上的发布版：

```bash
cd apps/fundrive
uv pip install -e ../fundrive-baidu      # 本地可编辑安装，覆盖 extra 里的发布版
```

跨仓库的统一安装入口是 `scripts/setup.sh install-dev <target>`，但它要求目标 app 自己有
`scripts/setup.sh` —— 目前五个 app 都还没有，见
[004-known-deviations.md](./004-known-deviations.md) 第 1 条。在那之前按上面的 `uv` 命令
手工操作。
