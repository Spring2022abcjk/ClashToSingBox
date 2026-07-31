# ClashToSingBox
PowerShell 模块 | Clash YAML → sing-box JSON 配置转换器

轻量、规范输出、可扩展的代理配置转换工具。

## 核心特性
- 纯 PowerShell 原生，无第三方依赖
- 非入侵架构，核心逻辑与扩展功能分离
- 输出干净：无空对象、无冗余字段、符合 sing-box 规范
- 支持 VMess / Shadowsocks / Trojan / VLESS / AnyTLS 协议
  - AnyTLS (sing-box `anytls` 出站)：支持 AnyTLS 专有字段，TLS 在 AnyTLS 上**默认启用**（YAML 中可省略 `tls` 字段）
- 内置 TLS / Transport / Multiplex 统一共享结构
- 外挂功能：一键导出节点名称列表
- 通过项目级 PSScriptAnalyzer 静态检查和 Pester 测试，稳定可用

## 参数说明
- `-InputFile`
  输入：Clash 格式 YAML 配置路径

- `-OutputFile`
  输出：sing-box 格式 JSON 配置路径

- `-ExportOutboundList`
  开关：导出节点名称列表（outbounds 数组格式）

- `-OutboundListOutputPath`
  可选：自定义节点列表输出路径

## 安装与导入

### 开发目录中直接导入

```powershell
Import-Module .\ClashToSingBox.psd1 -Force
Get-Command -Module ClashToSingBox
```

### 安装到当前用户模块目录

在发布到 PowerShell Gallery 或私有 PSResource 仓库前，可以先把本仓库作为本地模块安装使用：

```powershell
$ModuleRoot = Join-Path $HOME "Documents\PowerShell\Modules\ClashToSingBox\0.1.0"
New-Item -Path $ModuleRoot -ItemType Directory -Force
Copy-Item -Path .\ClashToSingBox.psd1, .\ClashToSingBox.psm1, .\Classes, .\Private, .\Public -Destination $ModuleRoot -Recurse -Force
Import-Module ClashToSingBox
```

安装后即可在任意目录使用：

```powershell
Convert-ProxyNodes -InputFile .\clash_config.yaml -OutputFile .\sing-box_config.json
```

### 未来发布后的预期用法

发布到 PowerShell Gallery 或私有 PSResource 仓库后，预期可以这样安装：

```powershell
Install-PSResource ClashToSingBox -Scope CurrentUser
Import-Module ClashToSingBox
```

## 输出示例
```json
{
  "type": "shadowsocks",
  "tag": "🇯🇵 日本W01",
  "server": "xxx.xxx.xxx.xxx",
  "server_port": 443,
  "method": "aes-256-gcm",
  "password": "your-password"
}
```

## 仓库结构

本项目当前按 PowerShell 模块的标准方式组织：

- `ClashToSingBox.psm1`：模块入口
- `Classes/`：共享类型定义
- `Private/`：解析、校验、转换等内部实现
- `Public/`：对外导出的命令
- `tests/`：单元测试与集成测试
- `test-inputs/`：测试输入样例
- `test-outputs/`：测试基线输出
- `outputs/`：手工运行生成的结果文件
- `docs/PROJECT_STRUCTURE.md`：更详细的目录整理标准
- `docs/GIT_BRANCH_WORKFLOW.md`：分支合并与清理流程

当前源码分层、模块清单和集成测试已经落地。后续维护可优先处理 WebSocket early-data 预留字段、保持文档与实现同步，并持续区分测试基线、临时产物和个人输入。

## 一、核心架构
 
- 基础公共字段： type / tag / server / server_port （全协议必选）
- 共享能力层：
    - TLS ：白名单控制，支持证书、uTLS、REALITY
    - Transport ：白名单控制，支持 WS 等传输方式
    - Multiplex ：第三套共享结构，预留扩展，当前不侵入输出
- 协议私有层：VMess / Shadowsocks / Trojan / VLESS / AnyTLS 的专属字段分别维护
- 输出规则：无值不输出、无空对象、无冗余默认字段
 
## 二、已支持协议
 
- VMess（部分支持 TLS + Transport）
- Shadowsocks（基础出站字段）
- Trojan（支持 TLS + Transport）
- VLESS（支持 TLS + Transport，flow 当前仅支持 xtls-rprx-vision）
- AnyTLS（支持 AnyTLS 出站配置）
  - 特性：
    - `password`：AnyTLS 连接密码（必填）
    - `idle_session_check_interval` / `idle_session_timeout` / `min_idle_session`：会话闲置相关配置，已实现并映射到输出
    - TLS 行为：在 AnyTLS 下 TLS 默认启用，代码会自动解析 `servername`、`fingerprint` 等 TLS 相关字段，即使 YAML 中未显式写 `tls: true`。

## 三、工程化质量
 
1. 静态检查：使用仓库根目录的项目级 PSScriptAnalyzer 配置，检查结果为空
2. 测试覆盖：基于 Pester，覆盖核心校验/转换逻辑和公开命令完整链路
3. 代码规范：遵循项目约定，保持缩进、命名和稀疏输出规则一致
 
## 四、扩展功能
 
- 功能：提取所有节点 tag，生成指定格式的 outbounds 列表
- 支持：
    - 开关触发： -ExportOutboundList 
    - 自定义输出路径： -OutboundListOutputPath 
    - 特性：完全不侵入核心转换逻辑，可独立移除
 
## 五、快速使用示例
 
1. 基础转换（Clash → sing-box）
 
```powershell
Convert-ProxyNodes -InputFile .\clash_config.yaml -OutputFile .\sing-box_config.json
```
 
2. 转换 + 导出节点名称列表（默认路径）
 
```powershell
Convert-ProxyNodes -InputFile .\clash_config.yaml -OutputFile .\sing-box_config.json -ExportOutboundList
```
 
3. 转换 + 自定义节点列表导出路径
 
```powershell
Convert-ProxyNodes -InputFile .\clash_config.yaml -OutputFile .\sing-box_config.json -ExportOutboundList -OutboundListOutputPath .\my_outbound_list.json
```

## 六、测试

运行单元测试：

```powershell
Invoke-Pester -Path .\tests\unit
```

运行集成测试：

```powershell
Invoke-Pester -Path .\tests\integration
```

运行全部测试：

```powershell
Invoke-Pester -Path .\tests
```

运行项目静态检查：

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse
```

仓库根目录的 `PSScriptAnalyzerSettings.psd1` 会被自动加载；静态检查结果应为空。
 
## 七、设计原则
 
- 共享逻辑抽离，避免重复
- 结构统一（TLS / Transport / Multiplex 风格一致）
- 输出干净、符合 sing-box 规范
- 可扩展：新协议只加专属逻辑，共享层不动
 
## 八、当前状态
 
- ✅ 现有单元测试和集成测试全部通过
- ✅ 转换稳定、输出无冗余
- ✅ 项目级 PSScriptAnalyzer 静态检查通过
- ✅ 可用于日常转换；生产使用前建议结合实际配置验证输出
- ✅ 已新增模块清单 `ClashToSingBox.psd1`，支持标准模块导入与后续 PSResource 发布
- ✅ 已支持 VLESS / Trojan / AnyTLS

## 九、许可证
[MIT License](./LICENSE)
