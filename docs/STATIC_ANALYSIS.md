# 静态检查规则基线

本项目使用仓库根目录的 `PSScriptAnalyzerSettings.psd1` 作为本地检查和
GitHub CI 的唯一 PSScriptAnalyzer 配置来源。

## 阻塞策略

配置启用 Error、Warning 和 Information 三种严重级别。使用该配置返回的
任何诊断都视为阻塞结果，需要修复或经过项目级评审后调整规则配置；CI 不把
Warning 或 Information 降级为仅报告信息。

本地检查命令：

```powershell
$analysis = @(
    Invoke-ScriptAnalyzer `
        -Path . `
        -Recurse `
        -Settings .\PSScriptAnalyzerSettings.psd1
)

$analysis

if ($analysis.Count -gt 0) {
    throw "PSScriptAnalyzer reported $($analysis.Count) blocking finding(s)."
}
```

后续 GitHub CI 必须使用相同的配置文件和非零结果失败策略，不得在工作流中
维护第二套排除列表。

## 排除规则

### `PSUseSingularNouns`

公开命令 `Convert-ProxyNodes` 已经是模块的稳定 API，并且名称准确表达一次转换
多个代理节点的行为。仅为满足通用命名规则而重命名会破坏现有调用方，因此保留
该项目级排除。新增公开命令仍应单独评审命名，不自动继承这一理由。

### `PSUseShouldProcessForStateChangingFunctions`

当前触发该规则的 `New-Shared*Config` 函数只构造内存对象，不修改文件、系统配置
或其他外部状态。为这些内部构造函数增加 `SupportsShouldProcess` 不提供有效保护。
未来新增真正修改外部状态的公开函数时，仍必须独立评估 `SupportsShouldProcess`
和 `-WhatIf`。

### `PSUseBOMForUnicodeEncodedFile`

项目运行基线是 PowerShell 7+，仓库文本采用跨平台 UTF-8、无 BOM 策略。
PowerShell 7 能可靠读取该编码，因此不为满足 Windows PowerShell 的历史兼容规则
批量改写文件。此排除不表示允许混用本地代码页或其他不明确编码。

## 基线变更规则

- 不通过新增内联抑制或扩大排除范围来掩盖普通缺陷。
- 调整规则时同步更新本文件和 `PSScriptAnalyzerSettings.psd1`。
- PSScriptAnalyzer 版本升级后重新运行完整扫描，确认没有新增未解释结果。
- 编码策略变化必须作为独立任务处理，不在功能改动中批量重写文件。
