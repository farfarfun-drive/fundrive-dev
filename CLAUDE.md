# fundrive-dev

编排仓库（dev repo）：本身不放应用代码，只记录五个子模块的 commit 指针，加跨仓库的
`scripts/` 与 `docs/`。完整治理约定见
[docs/project/project-governance/001-overview.md](docs/project/project-governance/001-overview.md)
—— 那是文档入口，含索引。

下面是在这个仓库里动手时最容易搞错的几条，按踩坑概率排序。

## 1. 子模块改动的提交顺序不能反

`apps/<name>` 下的文件属于**另一个 git 仓库**。改了那里的代码：

1. 先在 `apps/<name>` 里 commit，**push 到该 app 自己的 remote**；
2. 再回仓库根 `git add apps/<name>` 提交移动后的指针。

两条禁止项：不要在 app 仓库已 push 后把指针更新一直搁着（CI 的 `submodule-freshness`
每天会抓这个）；不要改了 `apps/` 里的文件却只在本仓库 commit —— 本仓库只能记录「我指向哪个
app commit」。动手前先 `git submodule status` 看清有没有意外的 `+` / `-`。

多个 app 为一次协调发布一起改时，把指针 bump 合并成**一个**本仓库 commit。

## 2. app 清单只有一个来源

`scripts/setup.sh` 的 `APP_REGISTRY` 是别名 / 路径 / PyPI 包名 / 类别的唯一来源。
`README.md` 和 `docs/` 里的表格是给人读的手写副本，改了登记表就得同步改它们，然后跑：

```bash
bash scripts/check-apps.sh      # 不一致就退出 1，CI 也跑这个
```

类别（`service` / `package`）由「有东西把它当长驻进程启动吗」决定，不从仓库名后缀推断。
五个 app 目前全是 `package`。

## 3. 共享版本号不要手改

五个包共用一个版本号，权威来源是 `scripts/funbuild.toml`，`funbuild` 每次 build 就地重写它。
**不要在文档或代码里复制这个值**，要读就读那个文件。版本号只能单调前进（原因见
`004-known-deviations.md` 第 3 条）。

## 4. 发布不是 setup.sh 的 action

```bash
bash scripts/build.sh            # = funbuild build，构建 + 发布 + 统一 push 一次
bash scripts/setup.sh <action> <target>   # 只管安装 / 升级 / 回滚（与服务生命周期）
```

## 5. 改完脚本要自己验

```bash
bash -n scripts/*.sh
shellcheck scripts/*.sh          # CI 要求零 finding，info 级也算
bash scripts/check-apps.sh       # app 清单在脚本与三张文档表格之间是否一致
bash scripts/check-links.sh      # 文档里的相对链接是否都能解析
```

`scripts/setup.sh` 的 release action 会真的装包，需要一个明确的目标环境：激活的 venv、
仓库根的 `.venv`，或显式 `FUNDRIVE_INSTALL_SYSTEM=1`。测试时用 `uv venv` 建一个临时的，
别往系统 python 里装。
