<#
.SYNOPSIS
Shadowsocks 专属校验
#>
function Invoke-SsValidator {
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
        -RequiredFields @("name", "server", "port", "cipher", "password") `
        -NonEmptyFields @("name", "server", "cipher", "password") `
        -FieldPrefix "SS"
    $ErrorMessages += $fieldErrors

    # 3. 端口校验
    $portResult = Get-ProxyPortValidationResult -Port $ProxyData.port `
        -ParseErrorMessage "SS port 必须是有效整数" `
        -RangeErrorMessage "SS port 必须在 1-65535 之间"
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

    # 5. 生成 SS 标准节点对象
    $multiplex = [MultiplexConfig]::new()

    $node = [PSCustomObject]@{
        Protocol   = "shadowsocks"
        Tag        = $ProxyData.name
        Server     = $ProxyData.server
        ServerPort = $portValue
        Method     = $ProxyData.cipher
        Password   = $ProxyData.password
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
