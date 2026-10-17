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
| `apps/fundrive-quark` | `quark` | package | [fundrive-quark](https://github.com/farfarfun-drive/fundrive-quark) | 夸克网盘 Web API 封装：分享链接解析、转存、文件列表、批量分享。**独立包**，见下 |

**五个 app 全是 package 类**：只会被 `import` / `pip install` 成依赖，没有任何东西把它们当
长驻进程启动，因此本工作区目前没有 service 类应用。「类别」决定哪些 action 对它有效，
分类依据见[发布与进程入口约定](docs/project/project-governance/003-release-and-entrypoint.md)。

这张表是手写副本，唯一来源是 `scripts/setup.sh` 的 `APP_REGISTRY`；
`bash scripts/check-apps.sh` 负责比对两者（CI 会跑），不一致就失败。

三个驱动仓库被核心库通过**可选依赖（extras）** 引用（`fundrive[alipan]`、`fundrive[baidu]`、
`fundrive[lanzou]`），同时也可以被第三方项目单独安装使用。
**`fundrive-quark` 是独立包**：核心库里既没有 `quark` drive 也没有 `quark` extra，
不能通过 `fundrive[quark]` 使用，要用就直接 `pip install fundrive-quark`
（取舍见[已知治理偏差](docs/project/project-governance/004-known-deviations.md)第 4 条）。

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
git add apps/ && git commit
```

子模块指针和 app 仓库的 commit 是两个仓库里的两个 commit，**app 仓库先 commit + push，
再在本仓库提交指针**，顺序不能反 —— 细节与禁止项见
[本地开发](docs/project/project-governance/002-local-development.md)。

## 常用命令

```bash
bash scripts/setup.sh install-dev all           # 五个 app 全部从工作树可编辑安装
bash scripts/setup.sh install-prod core 2.0.91  # 从索引装指定版本，省略版本=最新
bash scripts/setup.sh upgrade all
bash scripts/setup.sh rollback core 2.0.90      # 版本号必填
bash scripts/setup.sh                           # 不带参数：gum 交互选 action/target

bash scripts/build.sh                           # = funbuild build，构建 + 发布 + 统一 push
bash scripts/check-apps.sh                      # 校验 app 清单在脚本与文档间一致
```

`setup.sh` 的 release action 会真的装包，需要一个明确的目标环境（激活的 venv、仓库根的
`.venv`，或显式 `FUNDRIVE_INSTALL_SYSTEM=1`），不会默默装进系统 python。

`build` / `publish` **不是** `setup.sh` 的 action：构建发布由 `funbuild build` 自己 fan out，
递增 `scripts/funbuild.toml` 的共享版本号后发布每个 app，最后统一 push 一次。五个包共用这一个
版本号，所以**驱动包的版本号不再独立反映各自的改动幅度**，读变更要看各仓库的 `CHANGELOG.md`。

action 分组（两组的 `all` 含义不同）、交互菜单行为、共享版本号的来龙去脉，一律见
[发布与进程入口约定](docs/project/project-governance/003-release-and-entrypoint.md)
—— 这里不复述，避免两处漂移。

## 文档

从[项目治理总览](docs/project/project-governance/001-overview.md)开始 —— 它是文档入口，含完整索引。
跨 app 的产品级文档集中在本仓库 `docs/` 下，各 app 仓库不维护自己的 `docs/` 包。
在本仓库动手前先读 [CLAUDE.md](CLAUDE.md)，那是最容易踩的几条约定的速查版。

---

## 关于 farfarfun-drive

[farfarfun](https://github.com/farfarfun) 的网盘 / 云存储产品线：以
[fundrive](https://github.com/farfarfun-drive/fundrive) 的统一 `BaseDrive` 接口为核心，
配套各网盘的独立驱动包与蓝奏云 SDK / 桌面客户端。

- 🏠 组织主页：<https://github.com/farfarfun-drive>
- 📦 PyPI：<https://pypi.org/user/niuliangtao/>
- 📧 联系：farfarfun@qq.com

本项目基于 [MIT](LICENSE) 协议开源。
