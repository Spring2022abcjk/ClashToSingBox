<#
.SYNOPSIS
验证并将 Clash 代理节点转为标准化 ProxyNode 对象（路由分发）
#>
function Invoke-Validator {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$ProxyData,
        [string[]]$Filter
    )

    process {
        try {
            # ======================
            # 主函数，协议路由
            # ======================
            switch ($ProxyData.type) {
                "vmess" {
                    return Invoke-VmessValidator -ProxyData $ProxyData -Filter $Filter
                }
                "ss" {
                    return Invoke-SsValidator -ProxyData $ProxyData -Filter $Filter
                }
                "trojan" {
                    return Invoke-TrojanValidator -ProxyData $ProxyData -Filter $Filter
                }
                "vless" {
                    return Invoke-VlessValidator -ProxyData $ProxyData -Filter $Filter
                }
                "anytls" {
                    return Invoke-AnyTlsValidator -ProxyData $ProxyData -Filter $Filter
                }

                default {
                    return [PSCustomObject]@{
                        Node       = $null
                        IsValid    = $false
                        IsFiltered = $false
                        Errors     = @("不支持的协议: $($ProxyData.type)")
                    }
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                Node       = $null
                IsValid    = $false
                IsFiltered = $false
                Errors     = @($_.Exception.Message)
            }
        }
    }
}
