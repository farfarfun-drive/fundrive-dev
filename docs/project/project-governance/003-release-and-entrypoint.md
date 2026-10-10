# 发布与进程入口约定

本章记录本工作区怎么分类应用、哪些 action 对哪些 app 有效、构建发布怎么走。

## 应用分类

每个 `apps/<name>` 恰好属于一类（service / package / nested workspace），**由它实际做什么
决定，不从仓库名后缀推断**。分类必须在两处保持一致：根 `scripts/setup.sh` 的
`resolve_service_app()` / `resolve_package_app()`，以及 `README.md` 的应用表格。
两处不一致是缺陷，不是见解问题。

判定用的问题只有一个：**有东西把它当长驻进程启动、然后与之通信吗？** 是 → service；
只会被装成依赖 → package。结构上自己带 `apps/` + `scripts/setup.sh` 的 → nested workspace。

| 别名 | 路径 | 类别 | 判定依据 |
| --- | --- | --- | --- |
| `core` | `apps/fundrive` | package | 只会被 `import` / `pip install`；没有 `[project.scripts]`、没有 `__main__`、没有任何服务进程 |
| `alipan` | `apps/fundrive-alipan` | package | 阿里云盘开放平台 API 封装，纯库 |
| `baidu` | `apps/fundrive-baidu` | package | 百度网盘 PCS API 封装，纯库 |
| `lanzou` | `apps/fundrive-lanzou` | package | 蓝奏云 API 封装，纯库 |
| `quark` | `apps/fundrive-quark` | package | 夸克网盘 Web API 封装，纯库 |

**五个全是 package app。** 本工作区目前没有 service app，也没有 nested workspace app。
`resolve_service_app()` 因此是空的、`ALL_SERVICE_APPS` 是空数组 —— 这是如实反映现状，
不是漏填。将来 fundrive 长出带进程的 app（例如 `fundrive-api` HTTP 服务或一个同步守护
进程）时，要同时更新四处：`resolve_service_app()`、`ALL_SERVICE_APPS`、`TARGETS` /
`usage`，以及 `README.md` 的应用表格。

## action 分两组

根 `scripts/setup.sh <action> <target>` 是唯一的跨仓库入口，它只做分发 —— 转发给
`apps/<name>/scripts/setup.sh <action>`，不在本仓库重新实现安装或进程逻辑。
两组 action 的 `all` 含义不同，这是这套模式里最容易搞混的地方：

| 组 | action | `all` 展开为 |
| --- | --- | --- |
| service | `start` `stop` `restart` `run` `status` | 仅 service app —— 本工作区为空，`start all` 直接报错 |
| release | `install-dev` `install-prod [version]` `upgrade [version]` `rollback <version>` | service + package app：`core alipan baidu lanzou quark` |

- **`build` / `publish` 不是 `setup.sh` 的 action。** 构建发布由仓库根的 `funbuild build`
  自己 fan out（它认 `apps/` + `scripts/funbuild.toml` 这个布局），`scripts/build.sh`
  因此只有一行 `exec funbuild build`。
- 对分组外的目标执行 action（例如 `start core` —— `fundrive` 是 package，没有进程）是
  **用法错误，必须大声失败**，不能静默跳过。
- 缺 `<action>` 或 `<target>` 时退回 `gum choose` 交互菜单；参数写全的调用永远不碰
  `gum`，在 CI 里行为一致。`rollback` 缺版本号时直接报错，不进菜单 —— 回滚没有可交互的
  默认值。
- 多 app 时按脚本里 `ALL_RELEASE_APPS` 的声明顺序处理；`set -e` 下第一个失败即中止，
  不继续处理后面的 app。
- 目标 app 没检出、或还没有可执行的 `scripts/setup.sh` 时，脚本会说清楚缺的是什么，
  而不是把 `No such file or directory` 抛给调用方。

## 共享版本号与构建发布

`scripts/funbuild.toml` 的 `version` 是整个工作区**统一分发给所有 app** 的共享版本号，
而不是每个 app 各自维护版本。`funbuild build`（即 `bash scripts/build.sh`）的链路是：

1. 递增 `scripts/funbuild.toml` 的共享版本号；
2. 对 `apps/` 下每个已初始化、非 nested workspace 的子模块：切回远端默认分支（仅在
   detached 时）、`git pull`、转发 `funbuild build --version <共享版本号>`；
3. 最后在本仓库统一 `funbuild push` + 打 tag **一次**，使五个子模块指针的更新落成一个
   提交 —— 不是每个 app 一次 push。

子模块的处理顺序由 `git submodule status` 的输出决定（按路径字典序：`fundrive`、
`fundrive-alipan`、`fundrive-baidu`、`fundrive-lanzou`、`fundrive-quark`），所以核心库
先于驱动构建。这不影响正确性：核心库对驱动的引用是 extras 里的下界约束（`>=`），
在安装时才解析，不要求构建期拿到驱动的新版本。

共享版本号的权威来源是 `scripts/funbuild.toml` 本身 —— `funbuild` 每次 build 都会就地重写
它，所以**不要在文档里复制这个值**，要看就去读那个文件（或 `git tag` 列表）。
初始值取 `2.0.89`（当时五个 app 已发布版本里的最高值），这使四个驱动包从 1.x 并入了
2.0.x 版本线：取舍理由与对下游的含义见
[004-known-deviations.md](./004-known-deviations.md) 第 3 条。版本号只能单调前进。

`scripts/funbuild.toml` 还支持一个 `packages` 字段（构建前把命中的依赖抬到最新版），
本工作区**没有配置**它：`funbuild` 只扫 `[project.dependencies]`，而 `fundrive` 对四个
驱动的引用都在 `[project.optional-dependencies]` 里，配了也不会命中。不配空字段而留一个
假装生效的配置。

## 单个 app 内部的契约

每个 app 自己的 `scripts/setup.sh` 要支持 release action
（`install-dev` / `install-prod` / `upgrade` / `rollback` / `publish`）加 `build`，
但**不需要** `server start` 这类 service 子命令 —— package app 没有进程，给它硬塞一个
start/stop CLI 是伪造接口。细节见 `service-release-governance` 与 `bash-service-guide`
两个 skill；本编排仓库不代管 app 内部怎么实现。
