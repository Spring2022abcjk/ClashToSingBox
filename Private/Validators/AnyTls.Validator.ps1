<#
.SYNOPSIS
AnyTLS 专属校验
#>
function Invoke-AnyTlsValidator {
    [CmdletBinding()]
    param (
        [hashtable]$ProxyData,
        [string[]]$Filter
    )

    $ErrorMessages = @()

    # 1. 名称过滤
    if (Test-ProxyNameFiltered -ProxyData $ProxyData -Filter $Filter) {
        return [PSCustomObject]@{
            Node       = $null
            IsValid    = $false
            IsFiltered = $true
            Errors     = @()
        }
    }

    # 2. 必填字段与非空校验
    $fieldErrors = Test-RequiredFieldsAndNonEmpty -ProxyData $ProxyData `
        -RequiredFields @("name", "server", "port", "password") `
        -NonEmptyFields @("name", "server", "port", "password")
    $ErrorMessages += $fieldErrors

    # 3. 端口校验
    $portResult = Get-ProxyPortValidationResult -Port $ProxyData.port
    if (-not $portResult.IsValid) {
        $ErrorMessages += $portResult.Error
    }
    else {
        $portValue = $portResult.PortValue
    }

    if ($ErrorMessages.Count -gt 0) {
        return [PSCustomObject]@{
            Node       = $null
            IsValid    = $false
            IsFiltered = $false
            Errors     = $ErrorMessages
        }
    }

    # TLS 传输解析（AnyTLS 默认启用 TLS）
    # 创建 ProxyData 副本并强制设置 tls=true，确保所有 TLS 字段都被解析
    $proxyDataForTls = $ProxyData.Clone()
    $proxyDataForTls.tls = $true
    $tls = New-SharedTlsConfig -ProxyData $proxyDataForTls

    # AnyTLS 独有字段处理
    $anyTls = [AnyTlsConfig]::new()
    if ($ProxyData.'idle_session_check_interval') {
        $anyTls.idle_session_check_interval = [string]$ProxyData.'idle_session_check_interval'
    }
    if ($ProxyData.'idle_session_timeout') {
        $anyTls.idle_session_timeout = [string]$ProxyData.'idle_session_timeout'
    }
    if ($ProxyData.'min_idle_session' -and [int]::TryParse($ProxyData.'min_idle_session', [ref]$null)) {
        $anyTls.min_idle_session = [int]$ProxyData.'min_idle_session'
    }

    $node = [PSCustomObject]@{
        Protocol   = "anytls"
        Tag        = $ProxyData.name
        Server     = $ProxyData.server
        ServerPort = $portValue
        Password   = $ProxyData.password
        Tls        = $tls
        AnyTls     = $anyTls
        IsValid    = $true
        Errors     = @()
    }

    return [PSCustomObject]@{
        Node       = $node
        IsValid    = $true
        IsFiltered = $false
        Errors     = @()
    }
}
