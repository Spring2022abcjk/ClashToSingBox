# ClashToSingBox

将 Clash YAML 中的 `proxies` 节点转换为 sing-box JSON `outbounds` 的 PowerShell 模块。

当前版本：**1.0.0**

## 功能概览

- 支持 VMess、Shadowsocks、Trojan、VLESS 和 AnyTLS。
- 统一处理 TLS、uTLS、REALITY 与 WebSocket transport。
- 只输出有效字段，避免空对象和无意义默认字段。
- 可按节点名称正则过滤。
- 可额外导出节点 tag 列表。
- 提供 Pester 单元测试、集成测试和项目级 PSScriptAnalyzer 配置。

## 运行要求

- PowerShell 7.0 或更高版本。
- `powershell-yaml` 0.4.12 或更高版本，用于提供 `ConvertFrom-Yaml`。

安装依赖：

```powershell
Install-Module -Name powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser
```

确认环境：

```powershell
$PSVersionTable.PSVersion
Get-Command ConvertFrom-Yaml
```

## 安装

### 从源码导入

克隆仓库并安装依赖后，在仓库根目录执行：

```powershell
Import-Module .\ClashToSingBox.psd1 -Force
Get-Command -Module ClashToSingBox
```

### 安装到当前用户模块目录

```powershell
$ModuleRoot = Join-Path $HOME "Documents\PowerShell\Modules\ClashToSingBox\1.0.0"
New-Item -Path $ModuleRoot -ItemType Directory -Force
Copy-Item -Path .\ClashToSingBox.psd1, .\ClashToSingBox.psm1, .\Classes, .\Private, .\Public `
    -Destination $ModuleRoot -Recurse -Force
Import-Module ClashToSingBox -Force
```

> 当前仓库尚未声明已发布到 PowerShell Gallery。请不要把下面的命令当作当前可用的安装方式：
> `Install-PSResource ClashToSingBox`

## 快速开始

```powershell
Import-Module .\ClashToSingBox.psd1 -Force

$result = Convert-ProxyNodes `
    -InputFile .\clash-config.yml `
    -OutputFile .\outputs\outbounds.json

$result
```

成功时，`$result.Success` 为 `$true`，转换结果写入指定 JSON 文件。返回的 `ConversionResult` 还包含总数、成功数、失败数、过滤数、协议统计和错误信息。

按名称过滤节点：

```powershell
Convert-ProxyNodes `
    -InputFile .\clash-config.yml `
    -OutputFile .\outputs\outbounds.json `
    -Filter "到期|剩余流量|官网"
```

转换并导出节点名称列表：

```powershell
Convert-ProxyNodes `
    -InputFile .\clash-config.yml `
    -OutputFile .\outputs\outbounds.json `
    -ExportOutboundList `
    -OutboundListOutputPath .\outputs\outbound-list.json
```

## 完整输入示例

以下示例覆盖当前支持的五种协议，所有地址和凭据均为测试占位值：

```yaml
proxies:
  - name: example-vmess
    type: vmess
    server: vmess.example.com
    port: 443
    uuid: "11111111-1111-1111-1111-111111111111"
    cipher: auto
    tls: true
    sni: vmess.example.com
    network: ws
    ws-opts:
      path: /vmess
      headers:
        Host: edge.vmess.example.com

  - name: example-shadowsocks
    type: ss
    server: ss.example.com
    port: 8388
    cipher: aes-256-gcm
    password: "example-password"

  - name: example-trojan
    type: trojan
    server: trojan.example.com
    port: 443
    password: "example-password"
    tls: true
    servername: trojan.example.com
    network: ws
    ws-opts:
      path: /trojan
      headers:
        Host: edge.trojan.example.com

  - name: example-vless
    type: vless
    server: vless.example.com
    port: 443
    uuid: "22222222-2222-2222-2222-222222222222"
    flow: xtls-rprx-vision
    tls: true
    servername: vless.example.com
    client-fingerprint: chrome

  - name: example-anytls
    type: anytls
    server: anytls.example.com
    port: 443
    password: "example-password"
    servername: anytls.example.com
    skip-cert-verify: true
    idle_session_check_interval: 60s
    idle_session_timeout: 120s
    min_idle_session: 2
```

仓库中的 `test-inputs/integration-all-protocols.yml` 提供了可直接运行的同类测试输入。

## 支持字段

所有协议都要求：

| Clash 字段 | sing-box 字段 | 说明 |
| --- | --- | --- |
| `type` | `type` | 支持 `vmess`、`ss`、`trojan`、`vless`、`anytls` |
| `name` | `tag` | 节点名称，不能为空 |
| `server` | `server` | 服务器地址，不能为空 |
| `port` | `server_port` | 必须是 1–65535 的整数 |

协议私有字段：

| 协议 | 必填字段 | 可选或默认行为 |
| --- | --- | --- |
| VMess | `uuid` | `cipher` 默认 `auto`；`alterId` 默认 `0`；支持 TLS 和 WebSocket |
| Shadowsocks | `cipher`、`password` | 输出 `method`、`password`；不输出 TLS 或 WebSocket |
| Trojan | `password` | 支持 TLS 和 WebSocket |
| VLESS | `uuid` | `flow` 仅接受 `xtls-rprx-vision`；支持 TLS 和 WebSocket |
| AnyTLS | `password` | TLS 默认启用；会话空闲字段见下表 |

TLS、uTLS 与 REALITY 字段：

| 能力 | Clash 输入字段 |
| --- | --- |
| TLS | `tls`、`sni` / `servername`、`skip-cert-verify` |
| uTLS | `utls`、`fingerprint` / `client-fingerprint` |
| REALITY | `reality`、`reality-opts.public-key`、`reality-opts.short-id`，也支持顶层 `public-key`、`short-id` |
| WebSocket | `network: ws`、`ws-opts.path`、`ws-opts.headers` |

AnyTLS 字段：

| Clash 输入字段 | 行为 |
| --- | --- |
| `idle_session_check_interval` | 默认输出 `30s` |
| `idle_session_timeout` | 默认输出 `30s` |
| `min_idle_session` | 大于 `0` 时输出；`0` 不输出 |

## 暂不支持

- VMess、Shadowsocks、Trojan、VLESS、AnyTLS 之外的 Clash 协议。
- WebSocket 之外的 transport 类型。
- WebSocket `max_early_data` 和 `early_data_header_name`。
- Shadowsocks WebSocket transport。
- TLS `alpn`、`min_version` 等尚未接入 Validator 的预留字段。
- 从 Clash 输入解析 multiplex；当前类型和稀疏输出结构仅为后续扩展预留。
- 将节点合并进完整 sing-box 配置；当前输出是 outbound 对象数组。
- 转换 Clash 的 `proxy-groups`、`rules`、DNS 或其他顶层配置；只读取 `proxies`。

## 参数

| 参数 | 必需 | 说明 |
| --- | --- | --- |
| `-InputFile` | 是 | Clash YAML 输入路径 |
| `-OutputFile` | 是 | sing-box outbound JSON 输出路径 |
| `-Filter` | 否 | 节点名称的正则表达式数组；匹配节点会被排除 |
| `-JsonDepth` | 否 | JSON 序列化深度，默认 `10` |
| `-ExportOutboundList` | 否 | 同时导出节点 tag 列表 |
| `-OutboundListOutputPath` | 否 | tag 列表输出路径，仅与 `-ExportOutboundList` 一起使用 |

## 测试与静态检查

运行全部测试：

```powershell
Invoke-Pester -Path .\tests
```

分别运行单元测试和集成测试：

```powershell
Invoke-Pester -Path .\tests\unit
Invoke-Pester -Path .\tests\integration
```

运行项目静态检查：

```powershell
Invoke-ScriptAnalyzer `
    -Path . `
    -Recurse `
    -Settings .\PSScriptAnalyzerSettings.psd1
```

静态检查规则、排除项理由和阻塞策略见
[`docs/STATIC_ANALYSIS.md`](./docs/STATIC_ANALYSIS.md)。本项目把配置返回的
Error、Warning 和 Information 全部视为需要处理的阻塞结果。

校验模块清单：

```powershell
Test-ModuleManifest -Path .\ClashToSingBox.psd1
```

开发和测试需要 Pester、PSScriptAnalyzer：

```powershell
Install-Module -Name Pester -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

## 已知限制

- 单个节点验证失败时不会终止整批转换；失败节点会被跳过，错误记录在返回结果中。
- 只有至少一个节点转换成功时才写出输出文件。
- 输出是 sing-box outbound 数组，不是完整的 sing-box 配置文件。
- 默认输出以 UTF-8 无 BOM 编码写入。
- `-Filter` 使用 PowerShell 正则表达式语义，特殊字符需要正确转义。
- 项目测试覆盖当前实现路径，但不同 sing-box 版本或第三方 Clash 配置可能存在字段差异；实际使用前应检查生成结果。

## 安全提醒

- 不要向 Issue、Pull Request、日志或仓库提交真实订阅链接、代理节点、密码、UUID、Token 或 Authorization header。
- 示例和测试必须使用不可用的占位域名及占位凭据。
- 如果真实凭据曾进入 Git 历史，仅删除当前文件并不足够；应立即轮换凭据，并在公开前清理完整历史。
- `myinputs/`、`outputs/` 和私有 provider fixture 已通过 `.gitignore` 排除，不应作为测试事实来源。

## 当前版本状态

版本 `1.0.0`：

- 支持 VMess、Shadowsocks、Trojan、VLESS、AnyTLS 的核心转换链路。
- 支持 TLS、uTLS、REALITY 和 VMess/Trojan/VLESS 的 WebSocket `path`、`headers`。
- 支持 AnyTLS 默认 TLS 与会话空闲字段。
- 具备公开命令完整链路集成测试和协议级单元测试。
- 具备标准 PowerShell 模块清单和项目级 PSScriptAnalyzer 配置。
- 尚未发布到 PowerShell Gallery。

## 仓库结构

- `Classes/`：共享配置类型和转换结果类型。
- `Private/`：YAML 解析、共享校验、协议 Validator 和 Converter。
- `Public/`：公开命令 `Convert-ProxyNodes`。
- `tests/unit/`：单元测试。
- `tests/integration/`：完整输入到输出链路测试。
- `test-inputs/`：稳定测试输入。
- `test-outputs/`：正式测试基线。
- `outputs/`：本地临时输出，不纳入版本控制。
- `docs/`：项目结构和维护文档。

## 许可证

[MIT License](./LICENSE) — Copyright (c) 2026 petaljoe_
