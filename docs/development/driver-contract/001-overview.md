# 驱动接口契约与开发规范

本文档包是**跨仓库**的技术契约：`fundrive` 核心库定义的统一 `BaseDrive` 接口长什么样，
以及怎么写一个符合规范的网盘驱动。它对**所有**驱动实现生效 —— 核心库里的
`src/fundrive/drives/<name>/`，以及 `fundrive-alipan` / `fundrive-baidu` /
`fundrive-lanzou` / `fundrive-quark` 四个独立驱动包。

正因为它跨这五个仓库，所以留在本编排仓库，而不是任何单个 app 里。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-interface-contract.md](./002-interface-contract.md) | 统一接口的规范基准：方法签名、配置与调用约定、向上兼容要求 |
| [003-driver-development.md](./003-driver-development.md) | 驱动开发指南：项目架构、从零实现一个驱动、测试、文档规范、故障排除 |

## 权威性

接口的最终事实是代码，不是文档。遇到不一致时的优先级：

1. `fundrive` 的 [`src/fundrive/core/base.py`](https://github.com/farfarfun-drive/fundrive/blob/master/src/fundrive/core/base.py)
2. 本包 [002-interface-contract.md](./002-interface-contract.md)
3. 其余文档（`fundrive` 仓库的 `API.md` 等）

发现 3 与 1/2 冲突，是 3 需要改。

## 迁移说明

这两篇原先放在 `fundrive` 仓库（`INTERFACE-OPTIMIZATION.md` 与 `docs/DEVELOPMENT_GUIDE.md`），
2026-10-17 迁入本仓库 —— 它们约束的是五个仓库的共同行为，放在其中一个仓库里会让另外四个
的贡献者找不到。同一轮里 `fundrive` 自己的用法文档（`API.md`、`OPTIMIZATION.md`、快速入门）
留在了 `fundrive` 仓库，只是不再装在 `docs/` 包里。背景见
[已知治理偏差](../../project/project-governance/004-known-deviations.md)第 2 条。
