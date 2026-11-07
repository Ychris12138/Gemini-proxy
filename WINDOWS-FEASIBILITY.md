# Windows 可行性与验证计划

更新日期：2026-11-07。本文是方案研究；**项目目前只有经过一台 Mac 验证的 macOS 实现，没有 Windows 版，也没有 Windows 实机测试结果。**

## 先区分两个产品

Google 已提供 [Gemini Windows 桌面版](https://support.google.com/gemini/answer/18263854?hl=en)。不过，截至本次核查，Google 的 [桌面版介绍](https://gemini.google/desktop/) 将从 Gemini 内一键打开 Antigravity 列在 **macOS** 功能下；不能据此确认 Windows 版 Gemini 已有相同的内置组件或未来何时支持。

独立的 [Antigravity IDE](https://antigravity.google/download) 则提供 Windows 版本。它和 Gemini 桌面应用中的内置功能不是同一测试对象；已有项目支持独立 Antigravity，也不能直接证明支持 Gemini Windows 客户端。

## 能迁移什么

本项目 macOS 脚本依赖 `LSEnvironment`、`DYLD_INSERT_LIBRARIES`、Mach-O 动态库和 macOS 签名工具，**不能在 Windows 直接执行或复用编译产物**。可以迁移的是排查框架：查明主应用和辅助进程各使用什么网络栈，再分别处理代理，并让本机回环通信保持直连。

Windows 子进程通常继承父进程的环境变量，但父程序可以传入另一份环境；是否继承、程序是否使用 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`，都要针对实际程序验证。[Microsoft](https://learn.microsoft.com/en-us/windows/win32/procthread/environment-variables)；[Go net/http](https://pkg.go.dev/net/http#ProxyFromEnvironment)。不能仅因设置了变量就认为全部请求都会代理。

## 可研究的路线

1. **先验证程序自身支持的代理和进程环境变量。** 若 Windows 主程序和相关辅助进程本来就会读取代理配置，这是改动最少的路线；仍需测试 Google 授权、后续请求和回环地址，不能保证它适用于所有网络栈。Windows 的 [WinINet 和 WinHTTP 代理行为不同](https://learn.microsoft.com/en-us/windows/win32/winhttp/setting-wininet-proxy-configurations-in-winhttp)，具体还取决于程序实现。
2. **按进程透明转发。** 例如 [ProxyBridge Windows](https://github.com/InterceptSuite/ProxyBridge/blob/master/Windows/README.md) 通过 WinDivert 和用户规则转发 TCP/UDP；不必修改目标程序文件，但安装和运行需要管理员权限，底层驱动会接触系统级网络流量，再按规则处理。应排除 `127.0.0.1` 和 `::1`，并实测规则覆盖范围、代理不可用时的行为及 DNS/UDP；这条路线本项目尚未在 Windows 测试。
3. **Windows 专用动态库方案。** [yuaotian/antigravity-proxy](https://github.com/yuaotian/antigravity-proxy) 是面向独立 Antigravity 的 Windows 项目，可学习其主进程和子进程处理思路，但不能假设它对 Gemini Windows 桌面版有效。该路线需重新适配 Windows 的 DLL 加载、目标程序架构和安全策略；曾有用户报告特定版本发生[兼容性崩溃](https://github.com/yuaotian/antigravity-proxy/issues/146)。不应为了兼容而要求用户关闭杀毒、签名检查或系统保护。

建议先做第 1 条的诊断，再评估第 2 条能否覆盖不认代理的进程；只有确实需要时才研究第 3 条。若未来分发 ProxyBridge 相关驱动，还需独立核对其依赖的 [WinDivert 许可证](https://github.com/basil00/WinDivert) 和平台支持。

## Windows 实机验证所需证据

1. 记录 Windows、Gemini 或独立 Antigravity 的实际版本、安装方式和进程架构；确认测试的是哪个产品，以及是否真的存在内置 Antigravity 功能。
2. 在现有代理可用的前提下，分别观察目标程序的直接连接、仅设置进程级代理、按进程转发的结果；不改全局代理、路由或 TUN 作为默认步骤。
3. 分别验证登录、普通请求、相关辅助进程、内置本地服务（若存在）和停止代理后的表现。检查代理端实际连接，同时保留证书校验；不能只凭界面能打开或环境变量存在就判定全部流量被代理。
4. 测试更新后的兼容性，并在发布说明中记录版本、未覆盖流量和已知问题。分享日志前删除账号、令牌、本地文件路径和对话内容。

在完成上述 Windows 真实测试前，GitHub 仓库应标注 **macOS 已验证、Windows 待研究**，不要发布“Windows 已支持”的安装包或兼容性声明。
