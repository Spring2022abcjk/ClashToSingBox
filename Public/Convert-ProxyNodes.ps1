<#
.SYNOPSIS
Clash 转 sing-box 出站配置
#>
function Convert-ProxyNodes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$InputFile,

        [Parameter(Mandatory)]
        [string]$OutputFile,

        [string[]]$Filter,
        [int]$JsonDepth = 10,

        [switch]$ExportOutboundList,
        [ValidateScript({
                if ($PSBoundParameters.ContainsKey('OutboundListOutputPath') -and -not $ExportOutboundList) {
                    throw "参数 OutboundListOutputPath 只能在指定 -ExportOutboundList 时使用。"
                }
                $true
            })]
        [string]$OutboundListOutputPath
    )

    begin {
        $startTime = Get-Date
        $result = [ConversionResult]::new()
        $result.StartTime = $startTime
        Write-Verbose "开始转换，输入文件：$InputFile"
    }

    process {
        try {
            if (-not (Test-Path $InputFile)) {
                throw "输入文件不存在：$InputFile"
            }

            # 读取并解析 YAML
            $yamlContent = Get-Content -Path $InputFile -Raw -Encoding UTF8
            $parseResult = $yamlContent | Invoke-Parser

            if (-not $parseResult.Success) {
                $result.Errors += "解析失败: $($parseResult.Error)"
                return
            }

            $result.TotalCount = $parseResult.Count
            Write-Verbose "总代理节点数：$($result.TotalCount)"

            $proxies = @($parseResult.Proxies)
            if ($proxies.Count -eq 0) {
                $result.Errors += "YAML 中未找到任何 proxies 节点"
                return
            }

            # 逐个验证并转换
            foreach ($item in $proxies | Invoke-Validator -Filter $Filter) {
                if ($item.IsFiltered) {
                    $result.FilteredCount++
                    Write-Verbose "节点已过滤"
                    continue
                }

                if (-not $item.IsValid) {
                    $result.FailedCount++
                    $result.Errors += $item.Errors
                    Write-Verbose "节点验证失败：$($item.Errors -join '; ')"
                    continue
                }

                # 有效节点：转换 + 计数
                $node = $item.Node
                $proto = $node.Protocol.ToString().Trim()

                # 协议统计
                if (-not $result.ProtocolCounts.ContainsKey($proto)) {
                    $result.ProtocolCounts[$proto] = 0
                }
                $result.ProtocolCounts[$proto]++

                # 转换输出
                $outbound = $node | Invoke-Converter
                $result.Outbounds += $outbound
                $result.SuccessCount++
                Write-Verbose "转换成功：协议=$proto，名称=$($node.Tag)"
            }

            if ($result.Outbounds.Count -gt 0) {
                $result.Outbounds | ConvertTo-Json -Depth $JsonDepth |
                Set-Content -Path $OutputFile -Encoding UTF8NoBOM

                if ($ExportOutboundList) {
                    $outboundListFile = if ($OutboundListOutputPath) {
                        $OutboundListOutputPath
                    }
                    else {
                        $OutputFile -replace '\.json$', '.outbound_list.json'
                    }

                    Export-OutboundList -Outbounds $result.Outbounds -OutputFile $outboundListFile
                    Write-Verbose "出站名称列表已导出：$outboundListFile"
                }

                $result.Success = $true
                Write-Verbose "输出完成：$OutputFile"
            }
            else {
                $result.Errors += "没有可转换的节点"
            }
        }
        catch {
            $errMsg = "异常终止：$($_.Exception.Message)"
            $result.Errors += $errMsg
            Write-Verbose $errMsg
        }
    }

    end {
        $result.EndTime = Get-Date
        $result.Duration = $result.EndTime - $result.StartTime
        Write-Verbose "转换耗时：$($result.Duration)"
        return $result
    }
}

<#
.SYNOPSIS
提取节点名称，生成 outbounds 列表
#>
function Export-OutboundList {
    param (
        [Parameter(Mandatory)]
        [array]$Outbounds,  # 传入转换好的节点
        [string]$OutputFile # 导出到文件
    )

    # 仅提取有效 tag，输出为合法 JSON：{"outbounds": [...]}。
    $finalList = @(
        $Outbounds |
        ForEach-Object { $_.tag } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    $jsonContent = [ordered]@{ outbounds = $finalList } | ConvertTo-Json -Depth 3

    if ($OutputFile) {
        $jsonContent | Set-Content -Path $OutputFile -Encoding utf8NoBOM
        Write-Information "✅ 已导出节点列表 → $OutputFile"
    }
}
