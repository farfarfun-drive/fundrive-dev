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
bash scripts/init.sh      # git submodule update --init --recursive
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
git add apps/ && git commit
```

跟踪分支在 `.gitmodules` 里显式写成了 `branch = master`，所以 `--remote` 的目标不依赖
git 版本的默认行为（旧版 git 默认 `master`，2.28+ 默认远端 HEAD）。

`--remote` 之后子模块通常处于 detached HEAD；`funbuild build` 会在构建前自己切回远端默认
分支（只在确实 detached 时切，不打断手动切到的 feature 分支）。手工开发时如果要在子模块里
提交，先自己 `git -C apps/<name> switch master`，或者用这条一次把五个都带到 master：

```bash
git submodule foreach 'git checkout master && git pull --ff-only'
```

CI 的 `submodule-freshness` job 每天跑一次，比对 `HEAD` 里记录的指针与各 app `master` 的
最新 commit，落后就失败 —— 它守的就是上面「不要让 app 已 push 而指针没提交」那条。
它不做 PR 门禁：app 仓库有新 commit 不该让本仓库无关的 PR 变红。

> **坑**：在「已经拉到新 commit、但指针还没 `git add`」这个窗口里**不要跑
> `scripts/init.sh`**（`git submodule update`）—— 它会把子模块退回指针记录的那个 commit，
> 把你刚拉的东西悄悄撤掉。先 `git add apps/`，再做别的。

## 本地安装与验证

跨仓库的统一安装入口是 `scripts/setup.sh`。核心库与驱动联调时，一条命令把五个 app 全部从
工作树可编辑安装 —— 之后改任何一个 app 的源码都立刻生效，不用重装：

```bash
uv venv                                  # 在仓库根建一个目标环境（只需一次）
bash scripts/setup.sh install-dev all    # = uv pip install --editable apps/<每一个>
bash scripts/setup.sh install-dev baidu  # 只装某一个
```

release action 会真的装包，所以需要一个明确的目标环境：激活的 venv、仓库根的 `.venv`，
或显式 `FUNDRIVE_INSTALL_SYSTEM=1`。三者都没有时脚本直接报错，**不会**默默装进系统 python。

单个 app 自己跑测试时在它目录里用 uv（五个 app 都是 `pyproject.toml` + `uv.lock`）：

```bash
cd apps/fundrive
uv sync                                  # 装依赖（含 dev 组）
uv sync --extra baidu --extra lanzou     # 需要某个网盘驱动时按 extra 装
uv run pytest
```

这两条路不要混用：`install-dev` 装进的是仓库根的环境（跨 app 联调用），`uv sync` 装进的是
`apps/<name>/.venv`（单 app 测试用）。
