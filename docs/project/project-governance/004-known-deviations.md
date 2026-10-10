# 已知治理偏差

本章留档本工作区与 `submodule-workspace-governance` 及其配套 skill 之间尚存的差距。
每条写清楚**现状**、**为什么本轮不动**、**消除它的前提**。留档的目的是让下一个人看到的是
一个已知取舍，而不是一个被忽略的 bug。

## 1. 五个 app 都还没有自己的 `scripts/setup.sh`

**现状**：`service-release-governance` / `bash-service-guide` 要求每个 app（package 类也
一样）在自己仓库里提供 `scripts/setup.sh`，支持 `install-dev` / `install-prod` /
`upgrade` / `rollback` / `publish` 与 `build`。五个 app 目前都没有 `scripts/` 目录。

**影响**：根 `scripts/setup.sh` 的 release action 现在无法真正落地 —— 它会在分发前检查目标
app 的 `scripts/setup.sh` 是否存在可执行，缺失时报出这条偏差而不是抛一个
`No such file or directory`。本地安装暂时按
[002-local-development.md](./002-local-development.md) 里的 `uv` 命令手工操作。

**为什么本轮不动**：补这五个脚本要在五个独立 app 仓库里各提一个 commit 并 push，属于
app 仓库内部的发布实现，不是编排仓库的治理范围（「本 skill 管组合，不管 app 内部发生什么」）。
把它混进编排仓库这一轮改动里，会让「dev 仓库规范化」这个变更横跨六个仓库。

**消除前提**：按 `bash-service-guide` 的 package app 形态，在五个 app 仓库各自补一个
`scripts/setup.sh`（只要 release action + `build`，不要 `server` 子命令），各自 commit、
push，再在本仓库 bump 五个指针。

## 2. `apps/fundrive` 自己维护了一个 `docs/` 包

**现状**：`apps/fundrive/docs/` 下有 `API.md`、`QUICK_START.md`、`DEVELOPMENT_GUIDE.md`、
`OPTIMIZATION_GUIDE.md`、`AUDIT-2026-07.md`，根目录还有 `INTERFACE-OPTIMIZATION.md`。
规范要求 `apps/<name>` 不维护自己的 `docs/` 包，跨仓库与产品级文档集中到 dev 仓库的
`docs/`（例外只有 nested workspace app 和专职的 `<product>-doc` 仓库，`fundrive` 两者都不是）。

**影响**：产品级内容（接口规范、开发规范、审计记录）和 app 级内容（这个库怎么用）混在一个
仓库里，跨 app 的内容没有归属地。另外这些文件名不符合 `NNN-kebab-case.md` 的文档包编号规范。

**为什么本轮不动**：迁移要在 `fundrive` 仓库里删文件、在本仓库里新建文档包，是一个跨两个
仓库的内容搬运 —— 而且得先逐篇判断哪些是真正跨 app 的产品文档（该迁）、哪些是
`fundrive` 这个库自己的用法说明（该留，只是不该叫 `docs/` 包）。这是内容归属决策，
不是机械移动。

**消除前提**：逐篇定性后分两步走：真正跨 app 的部分迁入本仓库
`docs/development/<feature-slug>/` 并按 `001-overview.md` 起编号；`fundrive` 自己的用法说明
收进它的 `README.md` 或保留为非 `docs/` 包的单文件。迁完删旧路径，不让两套 canonical path
长期并存。

## 3. 共享版本号已把四个驱动包从 1.x 并到 2.0.90（已执行，留档）

这条不是待修的偏差，是一次**已发生且不可撤销**的版本线合并，记在这里供以后追溯。

**做了什么**：`scripts/funbuild.toml` 的初始共享版本号取 `2.0.89` —— 当时五个 app 已发布
版本里的最高值（`fundrive` 2.0.89、`fundrive-alipan` 1.3.15、`fundrive-baidu` 1.0.13、
`fundrive-lanzou` 1.2.75、`fundrive-quark` 1.0.4）。2026-10-10 首次 `funbuild build`
把它递增到 `2.0.90`，并用这一个版本号把五个包全部发布到 PyPI、各自打上 `v2.0.90` tag。
四个驱动包因此从 1.x 一次性并入 2.0.x 版本线。

**为什么是这个取舍**：`funbuild` 的编排仓库模式强制一个共享版本号，没有「各 app 保留自己
版本线」的选项。取低于 2.0.89 的值会让 `fundrive` 的版本号回退，索引上的 latest 解析会坏掉
（`pip` 仍会装回 2.0.89）。取最高值是唯一不破坏任何包版本单调性的选择；跳变只影响语义化
版本的「可读性」，不影响可解析性 —— `fundrive` 对驱动的 extras 约束都是 `>=` 下界，
跳到 2.0.90 依然满足。

**对下游的含义**：四个驱动包的版本号从此与 `fundrive` 同步前进，**不再独立反映各自的改动
幅度** —— 某个驱动一行没改也会随工作区发版号走。读这几个包的版本号时不要按语义化版本推断
变更大小，要看各仓库的 `CHANGELOG.md`。

**不要做的事**：不要为了「修正」版本号而把 `scripts/funbuild.toml` 调回 1.x —— 那会让
四个驱动包的版本号回退，索引上的 latest 解析会坏掉。共享版本号只能单调前进。

## 4. `fundrive-quark` 在核心库里没有对应的 drive 与 extra

**现状**：`apps/fundrive-quark` 已作为独立包发布（当前 2.0.90），但 `fundrive` 核心库里
既没有 `src/fundrive/drives/quark/`，`pyproject.toml` 的 `[project.optional-dependencies]`
里也没有 `quark` 这一项 —— 整个 `fundrive` 源码树里没有任何 `quark` 字样。
另外三个驱动都有对应的 drive 实现与 extra。

**影响**：这不是编排仓库的结构问题，所以不影响本轮规范化；但它意味着
`fundrive-quark` 要么是一个还没接进核心库的半成品，要么是一个只打算给第三方单独用的包。
哪一种，决定了它该不该继续留在本工作区的 `apps/` 下。

**为什么本轮不动**：这是产品归属决策，不是结构问题。它在 `apps/` 下、按 package 登记、
参与共享版本发布，这些都没错。

**消除前提**：确认它的定位。接进核心库 → 在 `fundrive` 里补
`src/fundrive/drives/quark/` 与 `quark` extra；定位是独立第三方包 → 在
`README.md` 的应用表格里把这一点写明，免得下一个人以为是漏接。

## 5. `docs/` 目前只有 `project/` 一个区域

**现状**：文档包规范定义了 `product|design|development|testing|retrospective|release`
六个生命周期区域，本仓库目前只有 `docs/project/project-governance/`。

**为什么是这样**：空目录放一个占位 `001-overview.md` 是造假 —— 这些区域要有真实的功能文档
包才值得建。按需要新增：有了跨 app 的架构或接口契约文档就建
`docs/development/<feature-slug>/`，有了协调发布就建 `docs/release/<date>-<issue-key>-<slug>/`，
每个包一律从 `001-overview.md` 起编号。
