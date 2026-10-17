# 发布与进程入口约定

本章记录本工作区怎么分类应用、哪些 action 对哪些 app 有效、构建发布怎么走。

## 应用分类

每个 `apps/<name>` 恰好属于一类（service / package / nested workspace），**由它实际做什么
决定，不从仓库名后缀推断**。

分类的唯一来源是根 `scripts/setup.sh` 里的 `APP_REGISTRY`（别名|路径|PyPI 包名|类别）——
脚本的可选 target、`all` 的展开、`usage` 文本全部由它派生，所以新增或删除 app 只改这一处。
`README.md`、[001-overview.md](./001-overview.md) 与本章的三张表格都是给人读的手写副本，
由 `scripts/check-apps.sh` 跟登记表比对（CI 的 `lint` job 会跑）：不一致就退出 1。
**不一致是缺陷，不是见解问题** —— 现在这句话有执行者了，不再靠下一个人同时记住几处。

判定用的问题只有一个：**有东西把它当长驻进程启动、然后与之通信吗？** 是 → service；
只会被装成依赖 → package。结构上自己带 `apps/` + `scripts/setup.sh` 的 → nested workspace。

| 别名 | 路径 | 类别 | 判定依据 |
| --- | --- | --- | --- |
| `core` | `apps/fundrive` | package | 只会被 `import` / `pip install`；没有 `[project.scripts]`、没有 `__main__`、没有任何服务进程 |
| `alipan` | `apps/fundrive-alipan` | package | 阿里云盘开放平台 API 封装，纯库 |
| `baidu` | `apps/fundrive-baidu` | package | 百度网盘 PCS API 封装，纯库 |
| `lanzou` | `apps/fundrive-lanzou` | package | 蓝奏云 API 封装，纯库 |
| `quark` | `apps/fundrive-quark` | package | 夸克网盘 Web API 封装，纯库；核心库无对应 drive 与 extra，独立发布 |

**五个全是 package app。** 本工作区目前没有 service app，也没有 nested workspace app。
登记表里因此没有任何 `service` 项，`start` 之类的 action 没有可用目标 —— 这是如实反映现状，
不是漏填。将来 fundrive 长出带进程的 app（例如 `fundrive-api` HTTP 服务或一个同步守护
进程）时，**在 `APP_REGISTRY` 里加一行、类别写 `service` 就够了**：可选 target、`all` 的
展开、`usage` 都是从登记表派生的。剩下要手工同步的只有三张文档表格，`check-apps.sh` 会告诉
你漏了哪张。

## action 分两组

根 `scripts/setup.sh <action> <target>` 是唯一的跨仓库入口。两组 action 的 `all` 含义不同，
这是这套模式里最容易搞混的地方：

| 组 | action | `all` 展开为 |
| --- | --- | --- |
| service | `start` `stop` `restart` `run` `status` | 仅 service app —— 本工作区为空，`start all` 直接报错 |
| release | `install-dev` `install-prod [version]` `upgrade [version]` `rollback <version>` | service + package app：`core alipan baidu lanzou quark` |

### 两组 action 由谁执行

这是本工作区对 skill 的一处有意偏离，写清楚免得下一个人以为是实现偷懒：

- **release action 由本仓库直接执行**，不转发。五个 app 都是没有 CLI、没有进程的纯库，
  「装一个包」就是一条 `uv pip install`：`install-dev` = `uv pip install --editable apps/<path>`，
  `install-prod` / `upgrade` / `rollback` = `uv pip install <pkg>[==<version>]`。
  让每个 app 仓库再背一个只包着 uv 的 `scripts/setup.sh` 是纯仪式，取舍留档见
  [004-known-deviations.md](./004-known-deviations.md) 第 1 条。
- **service action 仍然转发**给 `apps/<name>/scripts/setup.sh <action>`。进程怎么起、PID 文件
  在哪、健康检查怎么做，只有 app 自己知道，本仓库不重新实现。本工作区暂无 service app，
  这条路径要等登记了 `service` 类 app 才会被走到。

### 其余约定

- **`build` / `publish` 不是 `setup.sh` 的 action。** 构建发布由仓库根的 `funbuild build`
  自己 fan out（它认 `apps/` + `scripts/funbuild.toml` 这个布局），`scripts/build.sh` 只负责
  确认 `funbuild` 装了、然后 `exec` 它并原样转发参数。
- 对分组外的目标执行 action（例如 `start core` —— `fundrive` 是 package，没有进程）是
  **用法错误，必须大声失败**，不能静默跳过。
- 缺 `<action>` 或 `<target>` 时退回 `gum choose` 交互菜单；参数写全的调用永远不碰
  `gum`，在 CI 里行为一致。两种情况不进菜单而直接报错：`rollback` 缺版本号（回滚没有可交互
  的默认值），以及 service action 在没有任何 service app 时（菜单里全是死选项）。
- **版本号位置参数只有 `install-prod` / `upgrade` / `rollback` 接受。** `install-dev` 与
  service action 收到版本号就报错；参数超过三个也报错 —— 不静默忽略多出来的参数。
- release action 需要一个明确的目标环境：激活的 venv、仓库根的 `.venv`，或显式
  `FUNDRIVE_INSTALL_SYSTEM=1`。三者都没有时直接报错，**不会**默默装进系统 python。
- 多 app 时按 `APP_REGISTRY` 的声明顺序处理；`set -e` 下第一个失败即中止，
  不继续处理后面的 app。
- 目标子模块没检出时脚本会让你去跑 `scripts/init.sh`，而不是抛一个 `No such file or
  directory`。判定看的是 `apps/<name>/.git` 存不存在 —— git 会为未初始化的子模块留一个空
  挂载点目录，所以 `-d apps/<name>` 恒为真，判不出 plain clone 的状态。

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

`scripts/funbuild.toml` 还支持一个 `latest-packages` 字段（把命中的依赖下界抬到最新版，
`funbuild latest-deps` 单独跑它），本工作区**没有配置**它：`funbuild` 只扫
`[project.dependencies]`，而 `fundrive` 对驱动的引用都在 `[project.optional-dependencies]`
里，配了也不会命中。不配空字段而留一个假装生效的配置。

> 字段名是 `latest-packages`，不是 `packages` —— 写错了 `funbuild` 会直接忽略，不报错。

## 单个 app 内部的契约

**package app 不需要自己的 `scripts/setup.sh`。** 它的安装由编排仓库直接用 uv 完成（见上
「两组 action 由谁执行」），构建发布由 `funbuild build` fan out 时直接认 `pyproject.toml`，
两条路都不经过 app 侧脚本。给一个纯库塞一个只包着 uv 的分发脚本不增加任何能力。

**service app 必须有自己的 `scripts/setup.sh`**，支持 `start` / `stop` / `restart` / `run` /
`status`，并且 `start` 后台、`run` 前台、PID 文件由它自己（或它的 CLI）管。细节见
`bash-service-guide`；本编排仓库只负责把 action 转发进去，不代管它内部怎么实现。

两类 app 都**不需要** `publish` / `build` 这样的 app 侧 action —— 发布是工作区级的动作，
由共享版本号驱动，单个 app 自己发版会破坏「五个包同版本」这个前提。
