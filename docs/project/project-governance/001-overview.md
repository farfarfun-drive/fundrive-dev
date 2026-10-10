# 项目治理总览

本文档包收录适用于整个 `fundrive-dev` 工作区的治理约定：工作区形态、本地开发怎么起环境、
应用怎么分类、发布链路怎么走。产品、设计、技术、测试四类文档按功能拆在
`docs/product|design|development|testing/<feature-slug>/` 下，不放在这里。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-local-development.md](./002-local-development.md) | 子模块检出、跨仓库改动的提交顺序、本地安装与验证步骤 |
| [003-release-and-entrypoint.md](./003-release-and-entrypoint.md) | 应用分类、`scripts/setup.sh` 的 action 分组、共享版本号与构建发布链路 |
| [004-known-deviations.md](./004-known-deviations.md) | 与 skill 规范尚有差距的地方，以及消除每条差距的前提 |

## 工作区形态

`fundrive-dev` 是编排仓库（dev repo），本身不放任何应用代码，只记录五个子模块的 commit
指针，加跨仓库的 `scripts/` 与 `docs/`。自身受版本控制的文件仅限：`README.md`、
`.gitmodules`、`.gitignore`、`scripts/`、`docs/`。

五个子模块各自是独立 GitHub 仓库，有自己的 git 历史、issue 与发布节奏，要单独
commit / push：

| 路径 | 仓库 | 别名 | 类别 |
| --- | --- | --- | --- |
| `apps/fundrive` | `farfarfun/fundrive` | `core` | package（核心库） |
| `apps/fundrive-alipan` | `farfarfun/fundrive-alipan` | `alipan` | package（驱动） |
| `apps/fundrive-baidu` | `farfarfun/fundrive-baidu` | `baidu` | package（驱动） |
| `apps/fundrive-lanzou` | `farfarfun/fundrive-lanzou` | `lanzou` | package（驱动） |
| `apps/fundrive-quark` | `farfarfun/fundrive-quark` | `quark` | package（驱动） |

本工作区目前**没有** service 类应用，也**没有** nested workspace 类应用 —— 五个 app 全是
只被 `import` / `pip install` 的库，没有任何东西把它们当长驻进程启动。分类依据见
[003-release-and-entrypoint.md](./003-release-and-entrypoint.md)。

## 依赖关系

`fundrive` 核心库定义统一的 `BaseDrive` 接口与各网盘 drive 实现
（`src/fundrive/drives/<name>/`）；四个驱动仓库是底层网盘 API 的封装，被核心库通过
**可选依赖（extras）** 引用，而不是必装依赖：

```
fundrive[alipan] -> aligo + fundrive-alipan
fundrive[baidu]  -> fundrive-baidu
fundrive[lanzou] -> fundrive-lanzou + funfile
```

因此四个驱动仓库既服务于 `fundrive`，也可以被第三方项目单独 `pip install` 使用 ——
它们不是 `fundrive` 的内部实现细节。`fundrive-quark` 目前是个例外，见
[004-known-deviations.md](./004-known-deviations.md)。

## 约定来源

本工作区的治理约定来自 `farfarfun-skill--service-governance` 的三个 skill：
`submodule-workspace-governance`（编排仓库形态、子模块纪律、跨仓库脚本）、
`service-release-governance` 与 `bash-service-guide`（单个 app 内部的发布与进程入口契约）。
这里只写落到 fundrive 上的具体结论。
