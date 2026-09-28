# AGENTS.md

面向以后接手本仓库的 AI agent / 开发者。先读这份，再改代码。

## 项目定位

`ClashToSingBox` 是一个 PowerShell 模块，用于把 Clash YAML 中的 `proxies` 节点转换为 sing-box JSON `outbounds`。

当前重点是：

- 输出干净：不输出空对象、不输出无意义默认字段。
- 协议可扩展：共享能力和协议私有字段分层维护。
- 纯 PowerShell：不引入第三方运行时依赖。
- 测试先行：新增协议或字段时同步补 Pester 单元测试。

已支持协议：

- `vmess`
- `shadowsocks`
- `trojan`
- `vless`
- `anytls`

## 当前仓库结构

- `ClashToSingBox.psd1`：模块清单，声明版本、RootModule、导出函数和 PSResource 元数据。
- `ClashToSingBox.psm1`：模块入口，只负责按顺序加载类、私有函数、公开命令，并导出 `Convert-ProxyNodes`。
- `Classes/ProxyNode.ps1`：共享配置类型，例如 `TlsConfig`、`TransportConfig`、`MultiplexConfig`、`AnyTlsConfig`、`ProxyNode`、`ConversionResult`。
- `Private/Parser.ps1`：Clash YAML 解析。
- `Private/Validator.ps1`：协议路由入口，负责把原始 Clash 节点分发到对应协议 validator。
- `Private/Validation.Shared.ps1`：共享过滤、端口、必填字段、TLS/Transport 构造逻辑。
- `Private/Validators/`：各协议 validator，负责协议私有字段校验和内部节点对象组装。
- `Private/Converter.ps1`：内部节点对象到 sing-box outbound 的转换。
- `Public/Convert-ProxyNodes.ps1`：公开命令入口。
- `tests/unit/`：Pester 单元测试。
- `test-inputs/`：稳定测试输入样例。
- `test-outputs/`：期望输出或快照基线。
- `outputs/`：手工运行的临时结果，不要当成测试基线。
- `docs/`：项目结构和维护流程文档。
- `myinputs/`：个人输入/输出样例，可能包含真实使用数据；改动前要谨慎。

## 开发前检查

开始任务时先执行或查看：

```powershell
git status --short --branch
Get-ChildItem -LiteralPath . -Recurse -File | Select-String -Pattern "TODO|FIXME|计划中|待办|下一步"
```

注意：

- 不要覆盖用户未提交改动。
- `AGENTS.md` 目前可能是未跟踪文件，改动前先看 git status。
- README 里可能残留已删除文档的引用，改文档时顺手校对实际文件。

## 常用命令

运行单元测试：

```powershell
Invoke-Pester -Path .\tests\unit
```

运行集成测试：

```powershell
Invoke-Pester -Path .\tests\integration
```

运行静态检查：

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse
```

手工转换示例：

```powershell
Import-Module .\ClashToSingBox.psm1 -Force
Convert-ProxyNodes -InputFile .\test-inputs\all-test.yml -OutputFile .\outputs\all-test-outbounds.json
```

转换并导出节点名称列表：

```powershell
Convert-ProxyNodes -InputFile .\test-inputs\all-test.yml -OutputFile .\outputs\all-test-outbounds.json -ExportOutboundList
```

## 新增协议流程

新增协议时优先按这个顺序改：

1. 在 `Private/Validators/` 增加协议校验函数，并接入 `Private/Validator.ps1` 的主路由 `Invoke-Validator`。
2. 在 `Private/Converter.ps1` 增加协议私有字段输出。
3. 如需新共享结构，先扩展 `Classes/ProxyNode.ps1`，再让 Validator 和 Converter 复用它。
4. 在 `tests/unit/Validator.Tests.ps1` 增加必填字段、非法字段、主路由进入对应校验器的测试。
5. 在 `tests/unit/Converter.Tests.ps1` 增加输出字段测试。
6. 需要样例时，把输入放 `test-inputs/`，期望输出放 `test-outputs/`。
7. 更新 `README.md` 的支持协议、字段行为和当前状态。

不要为了单个协议复制一整套共享 TLS / Transport / Multiplex 逻辑。共享能力应保持在公共函数或共享类型里。

## 共享能力约定

TLS：

- Clash 字段如 `tls`、`servername`、`skip-cert-verify`、`client-fingerprint`、`reality-opts` 应在 Validator 阶段映射到 `TlsConfig`。
- AnyTLS 的 TLS 默认启用，即 YAML 中没有显式 `tls: true` 也应解析 TLS 相关字段。
- Converter 只输出非空、有效、符合 sing-box 语义的字段。

Transport：

- WebSocket transport 只适用于 VMess、Trojan、VLESS；不要为 Shadowsocks 输出 WebSocket transport。
- `WsTransportConfig` 支持 `max_early_data` / `early_data_header_name`；Validator、Converter 和测试需保持三者映射一致。

Multiplex：

- 当前作为共享结构预留和稀疏输出。
- 不要在协议分支里覆盖公共层已经生成的 multiplex 输出。

AnyTLS：

- `password` 必填。
- `idle_session_check_interval` 和 `idle_session_timeout` 默认值为 `30s`。
- `min_idle_session = 0` 时不输出。

## 输出规则

Converter 的核心原则：

- 保留 sing-box 必填字段：`type`、`tag`、`server`、`server_port`。
- 协议私有字段只在有意义时输出。
- 不输出空 hashtable、空数组、空字符串字段，除非该协议明确需要。
- 不输出冗余默认值，除非当前测试或 sing-box 语义要求保留。
- 输出字段名使用 sing-box 风格，例如 `server_port`、`packet_encoding`、`idle_session_timeout`。

改 Converter 时必须同步检查既有测试对“稀疏输出”的断言。

## PowerShell 风格

本项目默认使用 PowerShell 7+ / `pwsh`。

要求：

- 优先对象管道，不要解析字符串输出。
- 项目代码中不要使用别名，例如 `ls`、`cat`、`rm`、`?`、`%`。
- 路径使用 `Join-Path`、`Test-Path`、`Resolve-Path`。
- 公开函数使用 Verb-Noun 命名和 `[CmdletBinding()]`。
- 参数要强类型，必要时使用 `[ValidateNotNullOrEmpty()]`、`[ValidateSet()]`。
- 函数输出结构化对象；日志使用 `Write-Verbose`、`Write-Warning`、`Write-Error`。
- 库代码不要使用 `exit`。
- 不要使用 `Invoke-Expression` 执行拼接命令。

外部命令优先用参数数组：

```powershell
& git @("status", "--short", "--branch")
```

## PowerShell 红线

下面这些规则即使在小改动里也要遵守：

- 不要把 PowerShell 写成 Bash/cmd 风格。
- 不要在项目代码中使用别名，例如 `ls`、`cat`、`rm`、`cp`、`mv`、`?`、`%`、`iwr`、`irm`、`iex`。
- 不要使用 `Invoke-Expression` 执行拼接出来的命令。
- 不要把远程内容直接 pipe 到执行器，例如 `irm URL | iex` 或 `curl URL | bash`。
- 不要静默修改 PATH、profile、注册表、服务、系统目录或权限。
- 不要静默吞掉错误；只有失败是预期情况并且马上处理时，才使用 `-ErrorAction SilentlyContinue`。
- 不要用 `Write-Host` 当日志系统；优先使用 `Write-Verbose`、`Write-Debug`、`Write-Information`、`Write-Warning`、`Write-Error`。
- 不要在模块/库函数中使用 `exit`。
- 涉及创建、删除、覆盖、安装、卸载、修改配置的公开函数，应考虑 `SupportsShouldProcess` 和 `-WhatIf`。
- 涉及外部命令时要检查失败路径，不能假设命令成功。

## 文件和数据规则

- 新说明文档放 `docs/`，根目录只保留入口级文件。
- 新测试输入放 `test-inputs/`。
- 新期望输出放 `test-outputs/`。
- 临时运行结果放 `outputs/`，不要把它当事实来源。
- 不要随意改 `myinputs/`，除非任务明确要求或已经确认不含敏感内容。
- 不要提交 token、密码、真实订阅链接、Authorization header。

## 文档维护

改功能时至少检查：

- `README.md` 是否需要更新支持协议、字段说明、示例或当前状态。
- `docs/PROJECT_STRUCTURE.md` 是否仍符合实际目录。
- 不要引用不存在的文档文件。

当前已知文档债：

- README 仍可能提到已经不存在的 `docs/AI_REFACTOR_PLAN.md` 和旧架构文档。
- README 的“当前状态”里可能保留旧的“后续加 VLESS / Trojan”描述；实际已经支持。

## 完成标准

提交或交付前检查：

- `Invoke-Pester -Path .\tests\unit` 通过。
- `Invoke-Pester -Path .\tests\integration` 通过。
- 如环境有 PSScriptAnalyzer，运行 `Invoke-ScriptAnalyzer -Path . -Recurse`，或说明未运行原因。
- 新协议/字段有 Validator 和 Converter 测试。
- README 和 docs 没有明显过期引用。
- `git status --short` 中只有本任务相关改动。

## 优先级提示

如果继续整理这个项目，建议优先做：

1. 修正 README 中失效的文档引用和过期状态。
2. 为完整输入到输出链路补 `tests/integration/`。
3. 持续验证 WebSocket `max_early_data` / `early_data_header_name` 的字段映射和边界行为。
4. 明确 `myinputs/` 与 `outputs/` 是否进入版本管理。
