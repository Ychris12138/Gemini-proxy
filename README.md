<a name="gemini-proxy"></a>

# Gemini-proxy for macOS — Gemini, AGY CLI & Antigravity

在 macOS 上使用本机代理接入 **Gemini App**、**AGY 命令行**和**独立 Antigravity App**，无需开启 TUN。请先安装你需要的 Google 官方客户端，再选择对应的入口。

A community project for using Gemini, the Antigravity CLI (`agy`), and the standalone Antigravity app with a local proxy on macOS, without enabling TUN.

| 客户端 | 使用方式 | 在 Apple Silicon Mac 上的验证结果 |
| --- | --- | --- |
| **Gemini App**（含内置 Antigravity） | 创建并打开本地代理副本 | 已验证登录及内置 Antigravity。[使用指南](docs/gemini-macos.md) · [测试记录](TEST-RESULTS.md) |
| **AGY Command Line**（Antigravity CLI） | 在工作目录运行 `agy-proxy` | 已验证 Google 授权和实际模型回复。[CLI 使用指南](antigravity/README.md#安装和使用) |
| **Antigravity App**（独立桌面应用） | 完全退出应用后运行 `antigravity-proxy` | 已验证启动和后台连接本机代理，重新授权和模型回复仍待验证。[桌面 App 使用指南](antigravity/README.md#安装和使用) |

## 快速开始

启动本机代理并记下端口。下例使用 `127.0.0.1:10808`。Gemini 需要 SOCKS5 和 HTTP CONNECT；两个 Antigravity 启动器默认使用 HTTP CONNECT，SOCKS5 可选。

```sh
git clone https://github.com/Ychris12138/Gemini-proxy.git
cd Gemini-proxy
```

### Gemini App

先确认已安装官方 Gemini 和 Apple Command Line Tools。运行构建命令，阅读签名提示后打开生成的 `Gemini no-TUN.app`。**这个副本会在本地重签，失去 Google 原签名的完整性保护。** [签名、详细步骤与回退说明](docs/gemini-macos.md)

```sh
./create-proxy-copy.sh --socks-port 10808 --http-port 10808
```

### AGY CLI 与独立 Antigravity App

安装脚本同时提供两个启动器。它们向官方客户端传入代理环境变量，支持自定义代理端口。使用桌面启动器前，请先在 Antigravity 里按 `⌘Q` 完全退出。 [端口配置及登录排查](antigravity/README.md)

```sh
./antigravity/install.sh
```

- **AGY Command Line** 在你的工作目录运行 `~/.local/bin/agy-proxy`。
- **Antigravity App** 在终端运行 `~/.local/bin/antigravity-proxy`。

也可直接下载已有预发布包。[Gemini App 构建包](https://github.com/Ychris12138/Gemini-proxy/releases/tag/v0.1.0) · [AGY CLI 与 Antigravity App 安装包](https://github.com/Ychris12138/Gemini-proxy/releases/tag/antigravity-proxy-v0.1.0)

## 适用范围

这是社区项目，验证范围为一台 Apple Silicon Mac。各入口依赖不同的代理机制，覆盖范围见各自指南。Google 账号验证和服务地区资格仍由 Google 决定。Windows 目前只有可行性研究。 [Windows 可行性说明](WINDOWS-FEASIBILITY.md)

本仓库新增贡献采用 BSD 2-Clause。第三方源码保留各自的许可证和署名。 [许可证](LICENSE) · [第三方来源与许可](NOTICE.md)
