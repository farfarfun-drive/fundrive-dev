# fundrive-dev

fundrive 联合开发仓库，通过 Git 子模块固定统一网盘接口核心库与各网盘驱动的版本。
本仓库自身不放任何应用代码，只记录子模块指针加跨仓库的 `scripts/` 与 `docs/`。

## 项目

| 目录 | 别名 | 类别 | 项目 | 说明 |
| --- | --- | --- | --- | --- |
| `apps/fundrive` | `core` | package | [fundrive](https://github.com/farfarfun-drive/fundrive) | 核心库：统一的 `BaseDrive` 网盘操作接口与 20+ 网盘的 drive 实现 |
| `apps/fundrive-alipan` | `alipan` | package | [fundrive-alipan](https://github.com/farfarfun-drive/fundrive-alipan) | 阿里云盘开放平台 API 封装：扫码登录、文件列表/搜索、上传下载、分享 |
| `apps/fundrive-baidu` | `baidu` | package | [fundrive-baidu](https://github.com/farfarfun-drive/fundrive-baidu) | 百度网盘 PCS API 封装：上传下载、移动复制、离线下载、分享转存 |
| `apps/fundrive-lanzou` | `lanzou` | package | [fundrive-lanzou](https://github.com/farfarfun-drive/fundrive-lanzou) | 蓝奏云 API 封装：登录、文件/文件夹列表、上传下载、分享提取 |
| `apps/fundrive-quark` | `quark` | package | [fundrive-quark](https://github.com/farfarfun-drive/fundrive-quark) | 夸克网盘 Web API 封装：分享链接解析、转存、文件列表、批量分享 |

「类别」决定哪些 action 对它有效，见下文「安装 / 升级」。这一列必须与 `scripts/setup.sh` 里的
`resolve_service_app()` / `resolve_package_app()` 一致 —— 两处不一致是缺陷。
**五个 app 全是 package 类**：只会被 `import` / `pip install` 成依赖，没有任何东西把它们当
长驻进程启动，因此本工作区目前没有 service 类应用。分类依据见
[发布与进程入口约定](docs/project/project-governance/003-release-and-entrypoint.md)。

四个驱动仓库被核心库通过**可选依赖（extras）** 引用（`fundrive[baidu]`、`fundrive[lanzou]`、
`fundrive[alipan]`），同时也可以被第三方项目单独安装使用。

具体的安装、配置和开发方式见各子项目 README；跨仓库的开发流程见
[本地开发](docs/project/project-governance/002-local-development.md)。

## 快速开始：获取代码

首次克隆时同时拉取子模块：

```bash
git clone --recurse-submodules https://github.com/farfarfun-drive/fundrive-dev.git
cd fundrive-dev
```

已有仓库（或未使用 `--recurse-submodules` 克隆）可执行：

```bash
bash scripts/init.sh
```

## 更新子模块

```bash
git submodule update --remote
git add apps/fundrive apps/fundrive-alipan apps/fundrive-baidu apps/fundrive-lanzou apps/fundrive-quark
```

更新后的子模块提交由当前仓库记录，需要随父仓库一起提交。子模块指针和 app 仓库的 commit 是两个
仓库里的两个 commit，**app 仓库先 commit + push，再在本仓库提交指针**，顺序不能反
—— 细节见[本地开发](docs/project/project-governance/002-local-development.md)。

## 跨仓库入口

统一入口是 `scripts/setup.sh <action> <target>`，它只做分发 —— 转发给
`apps/<name>/scripts/setup.sh <action>`，不在本仓库重新实现安装或进程逻辑。

action 分两组，**两组的 `all` 含义不同**：

```bash
# 安装 / 升级：对 service + package 都有效，all = core alipan baidu lanzou quark
bash scripts/setup.sh install-dev all           # 从工作树构建并本地安装
bash scripts/setup.sh install-prod core 2.0.90  # 从索引装指定版本，省略版本=最新
bash scripts/setup.sh upgrade all
bash scripts/setup.sh rollback core 2.0.89      # 版本号必填

bash scripts/setup.sh                           # 不带参数：gum 交互选 action/target
```

服务生命周期 action（`start` / `stop` / `restart` / `run` / `status`）只对 service 类有效，
本工作区暂无 service app，这几个 action 目前没有可用目标；执行会直接报错退出。
对分组外的目标执行 action（例如 `start core` —— `fundrive` 是 package 类，没有进程）
同样直接报错，不静默跳过。

不带参数、或漏传 `target` 时，脚本会用 [`gum`](https://github.com/charmbracelet/gum)
弹交互菜单补全缺的部分；没装 `gum` 就必须把参数写全，脚本本身不负责装这个交互依赖。
`rollback` 漏版本号时直接报错而不是进菜单 —— 回滚没有可交互的默认值。

> release action 要求目标 app 自己有 `scripts/setup.sh`，目前五个 app 都还没有，
> 脚本会明确报出这一点。在补齐之前请按
> [本地开发](docs/project/project-governance/002-local-development.md)里的 `uv` 命令手工安装，
> 偏差留档见[已知治理偏差](docs/project/project-governance/004-known-deviations.md)第 1 条。

## 构建 / 发布

**`build` / `publish` 不是 `scripts/setup.sh` 的 action。** 构建发布由本仓库根的
`funbuild build` 自己 fan out（它认 `apps/` + `scripts/funbuild.toml` 这个布局）：

```bash
bash scripts/build.sh      # 等价于 funbuild build
```

它递增 `scripts/funbuild.toml` 的共享版本号，用这个版本构建并发布 `apps/` 下每个应用，
最后统一执行一次 `funbuild push`，把五个子模块指针的更新作为一次提交推送。

> 五个包共用一个版本号，权威来源是 `scripts/funbuild.toml`（`funbuild` 每次 build 就地重写它，
> 别在别处复制这个值）。**驱动包的版本号不再独立反映各自的改动幅度** —— 一行没改也会随工作区
> 发版号走，读变更要看各仓库的 `CHANGELOG.md`。背景见
> [已知治理偏差](docs/project/project-governance/004-known-deviations.md)第 3 条。

## 文档

从[项目治理总览](docs/project/project-governance/001-overview.md)开始 —— 它是文档入口，含完整索引。
跨 app 的产品级文档集中在本仓库 `docs/` 下，各 app 仓库不维护自己的 `docs/` 包。
