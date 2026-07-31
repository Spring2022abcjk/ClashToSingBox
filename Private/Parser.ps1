<#
.SYNOPSIS
从 Clash 格式 YAML 中解析出 proxies 节点数组
#>
function Invoke-Parser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [ValidateSet('File', 'String')]
        [string]$SourceType = 'String'
    )

    begin {
        $proxyList = @()
        $parseError = $null
    }

    process {
        try {
            # 1. 根据来源类型获取真实 YAML 文本
            $yamlRaw = switch ($SourceType) {
                'File' {
                    # 文件模式：Content 是路径
                    Get-Content -Path $Content -Raw -Encoding UTF8 -ErrorAction Stop
                }
                'String' {
                    # 字符串模式：直接使用 Content
                    $Content
                }
            }

            # 2. 解析 YAML
            $yamlObject = $yamlRaw | ConvertFrom-Yaml -ErrorAction Stop

            # 3. 提取 proxies
            if ($yamlObject -and $yamlObject.ContainsKey('proxies')) {
                $proxyList = @($yamlObject.proxies)
            }
            else {
                $parseError = 'YAML 中未找到 proxies 节点'
            }
        }
        catch {
            $parseError = "解析失败：$($_.Exception.Message)"
        }
    }

    end {
        [PSCustomObject]@{
            Success = [string]::IsNullOrEmpty($parseError)
            Proxies = $proxyList
            Count   = $proxyList.Count
            Error   = $parseError
        }
    }
}
