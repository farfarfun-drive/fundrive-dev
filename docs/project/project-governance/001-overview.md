# 项目治理总览

本文档包收录适用于整个 `fundrive-dev` 工作区的治理约定：工作区形态、本地开发怎么起环境、
应用怎么分类、发布链路怎么走。产品、设计、技术、测试四类文档按功能拆在
`docs/product|design|development|testing/<feature-slug>/` 下，不放在这里 —— 目前有
[驱动接口契约与开发规范](../../development/driver-contract/001-overview.md)一个。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-local-development.md](./002-local-development.md) | 子模块检出、跨仓库改动的提交顺序、本地安装与验证步骤 |
| [003-release-and-entrypoint.md](./003-release-and-entrypoint.md) | 应用分类、`scripts/setup.sh` 的 action 分组、共享版本号与构建发布链路 |
| [004-known-deviations.md](./004-known-deviations.md) | 与 skill 规范尚有差距的地方，以及消除每条差距的前提 |

## 工作区形态

`fundrive-dev` 是编排仓库（dev repo），本身不放任何应用代码，只记录五个子模块的 commit
指针，加跨仓库的 `scripts/` 与 `docs/`。自身受版本控制的文件仅限：`README.md`、
`CLAUDE.md`、`LICENSE`、`.gitmodules`、`.gitignore`、`.github/workflows/`、`scripts/`、
`docs/`。

五个子模块各自是独立 GitHub 仓库，有自己的 git 历史、issue 与发布节奏，要单独
commit / push：

| 路径 | 仓库 | 别名 | 类别 |
| --- | --- | --- | --- |
| `apps/fundrive` | `farfarfun-drive/fundrive` | `core` | package（核心库） |
| `apps/fundrive-alipan` | `farfarfun-drive/fundrive-alipan` | `alipan` | package（驱动） |
| `apps/fundrive-baidu` | `farfarfun-drive/fundrive-baidu` | `baidu` | package（驱动） |
| `apps/fundrive-lanzou` | `farfarfun-drive/fundrive-lanzou` | `lanzou` | package（驱动） |
| `apps/fundrive-quark` | `farfarfun-drive/fundrive-quark` | `quark` | package（驱动，独立包） |

本工作区目前**没有** service 类应用，也**没有** nested workspace 类应用 —— 五个 app 全是
只被 `import` / `pip install` 的库，没有任何东西把它们当长驻进程启动。分类依据见
[003-release-and-entrypoint.md](./003-release-and-entrypoint.md)。

这张表与 `README.md`、`003-release-and-entrypoint.md` 里的表格都是手写副本，唯一来源是
`scripts/setup.sh` 的 `APP_REGISTRY`，由 `scripts/check-apps.sh` 比对（CI 会跑）。

## 依赖关系

`fundrive` 核心库定义统一的 `BaseDrive` 接口与各网盘 drive 实现
（`src/fundrive/drives/<name>/`）；四个驱动仓库是底层网盘 API 的封装，被核心库通过
**可选依赖（extras）** 引用，而不是必装依赖：

```
fundrive[alipan] -> aligo + fundrive-alipan
fundrive[baidu]  -> fundrive-baidu
fundrive[lanzou] -> fundrive-lanzou + funfile
```

因此这三个驱动仓库既服务于 `fundrive`，也可以被第三方项目单独 `pip install` 使用 ——
它们不是 `fundrive` 的内部实现细节。

`fundrive-quark` **不在这个依赖关系里**：核心库既没有 `quark` drive 也没有 `quark` extra，
它只作为独立包发布给第三方直接安装。这是已经定下来的定位，不是漏接 —— 见
[004-known-deviations.md](./004-known-deviations.md) 第 4 条。

四个驱动包都把代码装进 `fundrives` 这个 **PEP 420 隐式命名空间包**
（`fundrives.aliopen` / `fundrives.baidu` / `fundrives.lanzou` / `fundrives.quark`），
四个发行包因此能共存在同一个环境里。谁要是在自己的 `src/fundrives/` 下加了 `__init__.py`，
就会把另外三个的 portion 遮掉 —— CI 的 `smoke` job 会把四个装在一起再一并 import 来守这条。

## 约定来源

本工作区的治理约定来自 `farfarfun-skill--service-governance` 的三个 skill：
`submodule-workspace-governance`（编排仓库形态、子模块纪律、跨仓库脚本）、
`service-release-governance` 与 `bash-service-guide`（单个 app 内部的发布与进程入口契约）。
这里只写落到 fundrive 上的具体结论。
