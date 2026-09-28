<#
.SYNOPSIS
VMess 专属校验
#>
function Invoke-VmessValidator {
    [CmdletBinding()]
    param (
        [hashtable]$ProxyData,
        [string[]]$Filter
    )

    $ErrorMessages = @()
    $ErrorMessages += Get-WebSocketTransportValidationErrors -ProxyData $ProxyData

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
        -RequiredFields @("name", "server", "port", "uuid") `
        -NonEmptyFields @("name", "server", "uuid")
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

    # TLS 传输解析
    $tls = New-SharedTlsConfig -ProxyData $ProxyData

    # WebSocket 传输解析
    $transport = New-SharedTransportConfig -ProxyData $ProxyData

    $multiplex = [MultiplexConfig]::new()

    $node = [PSCustomObject]@{
        Protocol            = "vmess"
        Tag                 = $ProxyData.name
        Server              = $ProxyData.server
        ServerPort          = $portValue
        Tls                 = $tls
        Transport           = $transport
        Multiplex           = $multiplex
        Uuid                = $ProxyData.uuid
        Security            = ($ProxyData.cipher ?? "auto")
        AlterId             = ($ProxyData.alterId ?? 0)
        GlobalPadding       = $false
        AuthenticatedLength = $true
        PacketEncoding      = ""
        IsValid             = $true
        Errors              = @()
    }

    return [PSCustomObject]@{
        Node       = $node
        IsValid    = $true
        IsFiltered = $false
        Errors     = @()
    }
}
