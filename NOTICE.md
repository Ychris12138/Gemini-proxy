# 来源与归属

- `src/` 基于 [TuningZhou/antigravity-proxy-forMac](https://github.com/TuningZhou/antigravity-proxy-forMac)，参考提交 `bdf95e9ccc95dbfd8c1fae4fd5a24d720db4c141`。原项目致谢 [yuaotian/antigravity-proxy](https://github.com/yuaotian/antigravity-proxy)。本项目的 macOS 实验仅对名为 `Gemini` 的进程启用 `connect()` 网络钩子，不启用原项目通过进程派生钩子主动注入子进程的机制、不改写沙箱包装器，也不启用自动更新。DYLD 环境变量的普通继承仍可能使其他子进程加载动态库；详见 README。原项目随附的 `LICENSE.txt` 原文保存在 [licenses/antigravity-proxy-forMac-LICENSE.txt](licenses/antigravity-proxy-forMac-LICENSE.txt)。
- `include/nlohmann/json.hpp` 是 [nlohmann/json](https://github.com/nlohmann/json) 3.12.0，MIT License，许可原文见 [licenses/nlohmann-json-MIT.txt](licenses/nlohmann-json-MIT.txt)。该单头文件也保留了 Hedley 组件的 `CC0-1.0` 标记，许可见 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)。
- Google Gemini 是 Google 的产品。本目录不包含 Gemini 应用、Google 二进制文件、账号凭据、聊天数据或运行日志。使用者需自行取得官方软件。

上游 [macOS 分支的 README](https://github.com/TuningZhou/antigravity-proxy-forMac/blob/bdf95e9ccc95dbfd8c1fae4fd5a24d720db4c141/README.md) 和[原项目 README](https://github.com/yuaotian/antigravity-proxy/blob/main/README.md) 均将项目标为 BSD-2-Clause；它们的 `LICENSE.txt` 文本列示了 MinHook 与 Hacker Disassembler Engine 的版权和条款，没有单独列明本次摘取的每个主项目源文件的版权人。本仓库保留原文和上游链接，新增贡献的许可证见 [LICENSE](LICENSE)；第三方源码保留其各自的版权和许可。
