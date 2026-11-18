# Antigravity macOS 免 TUN 启动器

本包给 Google 官方的独立 Antigravity App 和 Antigravity CLI（`agy`）传入进程级代理。适用于浏览器完成 Google 授权后，客户端请求 `oauth2.googleapis.com/token` 时因直连而超时的情况。Gemini App 内置 Antigravity 使用仓库首页的 [Gemini 方案](https://github.com/Ychris12138/Gemini-proxy#gemini-proxy)。

本包只包含脚本和文档。使用前请安装 [Google 官方 App 或 CLI](https://antigravity.google/download)，并启动本机 HTTP CONNECT 代理。默认端口为 `127.0.0.1:10808`。桌面启动器要求 macOS 的 `open` 支持 `--env`。

## 安装和使用

1. 从 [GitHub Release](https://github.com/Ychris12138/Gemini-proxy/releases/tag/antigravity-proxy-v0.1.0) 下载 ZIP 和同名 `.sha256` 文件。在下载目录校验并解压：

   ```sh
   shasum -a 256 -c Antigravity-proxy-v0.1.0.zip.sha256
   unzip Antigravity-proxy-v0.1.0.zip
   cd Antigravity-proxy-v0.1.0/antigravity
   ./install.sh
   ```

   已克隆仓库的用户也可从仓库根目录运行 `./antigravity/install.sh`。默认安装到 `~/.local/bin`。如果同名文件内容不同，安装会停止。已有启动器的用户可以先备份旧文件，或使用 `./install.sh --bin-dir "$HOME/antigravity-tools/bin"` 单独安装。

2. 保持本地代理运行、TUN 关闭，检查到 Google 登录服务的连通性：

   ```sh
   ~/.local/bin/agy-proxy --proxy-check
   ```

   检查发送一个不带凭据的 HTTPS GET。Google 返回 HTTP 响应（例如 404）表示该连接已到达服务。实际 OAuth 令牌交换要在登录时单独验证。

3. **CLI**：在终端进入要使用的工作目录，运行 `~/.local/bin/agy-proxy`。按 CLI 提示完成 Google OAuth。如果浏览器显示一次性授权码，只贴回本次启动的 CLI。登录后发送一句“请只回复 OK”，确认实际收到模型回复。
4. **桌面 App**：如独立 Antigravity 已经在运行，先在应用中按 `⌘Q` 退出。运行 `~/.local/bin/antigravity-proxy`，从弹出的应用完成登录，然后发送一条测试消息。之后每次新启动都使用此命令。

若 `~/.local/bin` 已在 `PATH` 中，可以直接输入 `agy-proxy` 或 `antigravity-proxy`。如果想在交互式 zsh 继续输入 `agy`，可自行把 `alias agy="$HOME/.local/bin/agy-proxy"` 添加到 `~/.zshrc`，然后开一个新终端。原始 CLI 路径仍可用于诊断。

## 端口和路径配置

以下变量在运行启动器时指定。代理地址固定为本机回环地址 `127.0.0.1`，支持无认证的本地 HTTP CONNECT 和 SOCKS5。

| 变量 | 用途 | 默认值 |
| --- | --- | --- |
| `AG_PROXY_HTTP_PORT` | 本地 HTTP CONNECT 端口。Google OAuth 使用这里的 HTTP 代理 | `10808` |
| `AG_PROXY_SOCKS_PORT` | 可选 SOCKS5 端口，经 `ALL_PROXY` 传给遵守该变量的客户端 | 空 |
| `AGY_BIN` | 官方 `agy` 可执行文件的路径 | 从 `PATH` 查找，找不到时检查 `~/.local/bin/agy` |
| `ANTIGRAVITY_APP` | 独立 App 的安装路径 | `/Applications/Antigravity.app` |

```sh
AG_PROXY_HTTP_PORT=7890 ~/.local/bin/agy-proxy
AG_PROXY_HTTP_PORT=7890 AG_PROXY_SOCKS_PORT=7891 ~/.local/bin/antigravity-proxy
```

## 工作原理和排查

- `agy-proxy` 设置 `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY` 及其小写版本，然后把参数和当前目录交给官方 `agy`。桌面启动器用 `open --env` 给新启动的 App 传入同样的变量。两者均将 `localhost`、`127.0.0.1`、`::1` 保留给本机回调，并以包内的值取代继承的代理变量，避免已有 `NO_PROXY=*` 等设置让 OAuth 走直连。子进程可能继承这些变量，具体取决于客户端实现。
- 如果仍出现 `token exchange failed` 或 `dial tcp … i/o timeout`，先确认启动器确实被使用，再运行 `--proxy-check`。桌面应用应彻底退出后重启，macOS 复用旧进程时不会注入新的启动环境。
- 如果 OAuth 已完成，但出现 `VALIDATION_REQUIRED` 或地区资格提示，请检查 Google 账号验证与服务地区。这个包处理客户端的代理连接；是否允许使用服务由 Google 判定。 [Antigravity 官方认证说明](https://antigravity.google/docs/install?tab=cli) · [地区资格说明](https://antigravity.google/docs/faq/)
- 桌面版通常把后台日志写在 `~/Library/Logs/Antigravity/language_server.log`，CLI 通常写在 `~/.gemini/antigravity-cli/log/`。反馈问题时提供出错时间和脱敏错误行即可。

## 验证、更新与回退

- 在一台 Apple Silicon Mac 上关闭 TUN 测试。此前使用同类启动方式，CLI 已用 Pro 账号完成 Google OAuth 并获得回复。本发布包的启动器在默认 HTTP 端口下也用 CLI 1.5.11 的现有会话获得了实际模型回复。独立 App 2.31.2 可通过本包启动，后台语言服务已观察到连接本地代理。桌面端重新授权及实际模型回复仍待验证。
- Google 更新 App 或 CLI 后，原安装路径仍可用时，直接用相应启动器复测。更新本包时，先备份两个旧启动器，再运行新包的安装脚本。
- 回退时退出 App 或 CLI，删除本包安装的两个启动器；若添加过 zsh 别名，删除该行并开一个新终端。官方 App、CLI 以及它们的账号数据由各自程序管理。

## 从源码打包

在仓库根目录以已提交的版本打包，可用提交哈希代替下列 `HEAD` 固定源码：

```sh
git archive --format=zip --prefix=Antigravity-proxy-v0.1.0/ \
  -o Antigravity-proxy-v0.1.0.zip HEAD antigravity LICENSE
shasum -a 256 Antigravity-proxy-v0.1.0.zip > Antigravity-proxy-v0.1.0.zip.sha256
```
