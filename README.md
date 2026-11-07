# Gemini-proxy

让本机已安装的 Gemini macOS 应用在不启用 TUN 的情况下尝试使用本地代理，并覆盖其内置 Antigravity 服务。

An experimental no-TUN proxy setup for the Gemini macOS app and its built-in Antigravity service.

**社区实验，非 Google 官方软件。脚本会制作并本地重签 Gemini 副本；该副本失去 Google 原签名的完整性保护。本工具不保证所有流量经代理，也不是防泄漏工具。请先阅读下方的限制。**

当前仅在一台 Apple Silicon Mac 上验证；Windows 尚不支持，参见 [Windows 可行性说明](WINDOWS-FEASIBILITY.md)。

## 测试状态

2026-11-07 在一台 Apple Silicon、macOS 26.6.2、Gemini 1.131.4.1198 的 Mac 上，先用手工隔离副本验证，再从交付 ZIP 全新解压并执行脚本，由用户实际完成生成副本的登录和 Antigravity 测试。观察到 `agy` 子进程连接本地代理，服务从启动到就绪约 4 秒；脚本没有启用 TUN。详见 [测试记录](TEST-RESULTS.md)。

本结果只覆盖这台机器上的上述配置，不能证明全部流量均经代理。Intel Mac、其他 macOS 或 Gemini 版本尚未验证。测试后仅更新了说明和测试记录，脚本及动态库源码保持原样。

## 前提

- 已从 Google 安装并能通过系统签名验证的 `/Applications/Gemini.app`。脚本检查包 ID 和 Google Team ID；未来 Google 更换签名身份时，需要更新脚本。
- 本地已有运行中的、无账号密码认证的 SOCKS5 代理，以及 HTTP CONNECT 代理。两者可以是同一个混合端口，也可以分开；仅支持本机 `127.0.0.1`。
- Apple Command Line Tools（含 `clang++`、`python3`）和足够空间容纳一份 Gemini 副本。尚未安装时可在终端执行 `xcode-select --install`。
- 浏览器能够完成 Google 登录。脚本预检会通过本地代理请求 Google 的 `generate_204` 测试地址。

## 使用步骤

1. 获取本仓库，在终端进入项目目录：

   ```bash
   git clone https://github.com/Ychris12138/Gemini-proxy.git
   cd Gemini-proxy
   ```

2. 打开自己的代理软件，保持 TUN 关闭，记下 SOCKS5 和 HTTP CONNECT 端口。下例中两者均为 `10808`；如果你的端口不同，分别填写实际值。
3. 在项目目录运行：

   ```bash
   ./create-proxy-copy.sh --socks-port 10808 --http-port 10808
   ```

   若原版不在默认路径或希望自选输出位置：

   ```bash
   ./create-proxy-copy.sh \
     --source "/Applications/Gemini.app" \
     --output "$HOME/Applications/Gemini no-TUN.app" \
     --socks-port 10808 --http-port 10808
   ```

4. 阅读终端显示的签名与安全提示，输入 `YES`。脚本检查原版签名和两个代理端口，编译必要的动态库，创建一份独立副本并做本地签名；不会覆盖已有输出。
5. 保持本地代理运行，在访达打开生成的 `Gemini no-TUN.app`。按 Google 的正常流程登录，再在应用中打开 Antigravity 测试。
6. **不要移动生成的副本**：当前版本把动态库的绝对路径写入副本配置。要换位置，请在新位置重新生成。Gemini 更新后也应重新生成和验证，而不是覆盖原版或旧副本。由该脚本生成的副本共用同一个 Bundle ID；打开新副本前请退出旧副本，它们也可能共用本地数据。

两个端口的检查都必须通过：前者供主程序动态库使用，后者供 `agy` 等继承环境变量的子进程使用。若代理本身只提供 SOCKS5、没有 HTTP CONNECT 入口，需要先配置可用的 HTTP 代理；不能假定所有代理软件的端口相同。

## 工作原理

1. 不修改 `/Applications/Gemini.app`，从它复制出一个 Bundle ID 独立的应用。
2. 副本通过 `LSEnvironment` 加载一个本地动态库，拦截主进程中符合条件的 `connect()`；IPv4 的 TCP 80/443 连接尝试转给本机 SOCKS5，回环及默认私有地址直连。非回环 IPv6 连接在该钩子里失败，以便应用有机会回退到 IPv4。
3. 同时向副本设置 `HTTP_PROXY` / `HTTPS_PROXY` 和小写版本，使正常继承环境变量的 `agy` 子进程使用 HTTP CONNECT 代理；`NO_PROXY` 排除 `localhost`、`127.0.0.1` 和 `::1`。这个设置可能也被其他继承变量的子进程使用。
4. 应用内的 Antigravity 页面与 `agy` 之间仍通过 `127.0.0.1` 通信，不应把本地健康检查连接送入外部代理。

## 重要限制和回退

- 副本经过 ad-hoc 本地重签名，并允许 DYLD 环境变量、关闭该副本的库签名校验。**它不再具有 Google 原签名的完整性保护**；注入的代码运行在应用进程中，理论上可以访问该应用可访问的数据。请先审阅源码，再决定是否使用。
- 改变 Bundle ID 和签名身份可能导致需要重新登录、无法使用原有钥匙串或应用组，并可能影响小组件、文件关联或其他功能。为了避免接管原版关联，副本移除了原版的 URL 与文档类型注册；Google 后续修改登录方式时也可能因此失效。
- 动态库只对名为 `Gemini` 的目标进程启用 `connect()` 钩子，不覆盖 `connectx()`、UDP、所有子进程或所有目标端口；代理环境变量也只对遵守它的程序有效。DYLD 变量可能随环境传给其他子进程；如果其签名和系统策略允许，它们也可能加载动态库，但本库不会为其他名称启用网络钩子。本次实测的 `agy` 没有映射此动态库，而是通过 HTTP 代理变量连接。DNS、其他网络 API、非 80/443 端口等可能直连。**请勿依赖本工具保证隐私、匿名或阻止直连。**
- 脚本本身不修改原版、系统代理、TUN、路由或防火墙，也不安装后台守护进程。退出副本并打开原版即可回退。如要删除副本，请先退出它，再由用户自行移至废纸篓。副本失败后脚本可能留下未完成的输出目录，不会自动删除。建议在官方原版完成更新，再为新版本生成副本；副本内自动更新的行为尚未验证。
- 如果代理不可用，部分连接会失败；不能由此推断所有直连都被阻断。日志可能含目标 IP；提交 Issue 前请移除账户、令牌、本机路径、对话和网络日志。

## 离线检查

在项目目录运行：

```bash
python3 tests/smoke.py
```

该测试只在本机创建模拟 SOCKS5 服务，检查代理握手、回环直连和配置缺失时的拦截行为；不访问 Google，也不能替代真实 Gemini 的 GUI 测试。

## 来源

动态库为 [TuningZhou/antigravity-proxy-forMac](https://github.com/TuningZhou/antigravity-proxy-forMac) 的本地精简改造，固定参考提交 `bdf95e9ccc95dbfd8c1fae4fd5a24d720db4c141`：这里只启用 `connect()` 钩子，不通过进程派生钩子主动注入子进程、不更改沙箱包装器、不启用 FakeIP、自动更新或通知。详见 [NOTICE.md](NOTICE.md)。

其他相关项目：[ProxyBridge](https://github.com/InterceptSuite/ProxyBridge) 使用 macOS 网络扩展按应用转发，理论上可以保留原版签名，但本次尚未启用和验证；[mac-antigravity-proxy-dylib](https://github.com/OkamiFeng/mac-antigravity-proxy-dylib) 面向独立 Antigravity；[gemini-mac-no-tun](https://github.com/garybeyond/gemini-mac-no-tun) 虽然名称写免 TUN，其文档实际使用 TUN 设备和路由，不符合本项目的无 TUN 目标。

## 许可证

本仓库的新增贡献采用 [BSD 2-Clause](LICENSE)。第三方源码的署名、原始许可和许可范围说明见 [NOTICE.md](NOTICE.md) 及 [licenses](licenses/)。
