<#
.SYNOPSIS
Trojan 专属校验
#>
function Invoke-TrojanValidator {
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

    $multiplex = [MultiplexConfig]::new()

    # TLS 传输解析
    $tls = New-SharedTlsConfig -ProxyData $ProxyData

    # WebSocket 传输解析
    $transport = New-SharedTransportConfig -ProxyData $ProxyData

    $node = [PSCustomObject]@{
        Protocol   = "trojan"
        Tag        = $ProxyData.name
        Server     = $ProxyData.server
        ServerPort = $portValue
        Password   = $ProxyData.password
        Tls        = $tls
        Transport  = $transport
        Multiplex  = $multiplex
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
