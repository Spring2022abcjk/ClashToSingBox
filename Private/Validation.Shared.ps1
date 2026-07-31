function Test-ProxyNameFiltered {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [hashtable]$ProxyData,
        [string[]]$Filter
    )

    if (-not $Filter -or -not $ProxyData.name) {
        return $false
    }

    $matchedFilters = @($Filter | Where-Object { $ProxyData.name -match $_ })
    return ($matchedFilters.Count -gt 0)
}

function Get-ProxyPortValidationResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Port,

        [string]$ParseErrorMessage = "port 必须是有效的整数",
        [string]$RangeErrorMessage = "port 必须在 1-65535 之间"
    )

    $portValue = 0
    if (-not [int]::TryParse($Port, [ref]$portValue)) {
        return [PSCustomObject]@{
            IsValid   = $false
            PortValue = 0
            Error     = $ParseErrorMessage
        }
    }

    if ($portValue -lt 1 -or $portValue -gt 65535) {
        return [PSCustomObject]@{
            IsValid   = $false
            PortValue = $portValue
            Error     = $RangeErrorMessage
        }
    }

    return [PSCustomObject]@{
        IsValid   = $true
        PortValue = $portValue
        Error     = $null
    }
}

function New-SharedTlsConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$ProxyData
    )

    $tls = [TlsConfig]::new()
    $tls.enabled = $ProxyData.tls -eq $true
    if ($tls.enabled) {
        $serverName = ($ProxyData.sni ?? $ProxyData.servername)
        $tls.server_name = $serverName
        $tls.insecure = $ProxyData['skip-cert-verify'] -eq $true
        $tls.disable_sni = [string]::IsNullOrWhiteSpace($serverName)

        $fingerprint = ($ProxyData.fingerprint ?? $ProxyData['client-fingerprint'])
        if (($ProxyData.utls -eq $true -or -not [string]::IsNullOrWhiteSpace($fingerprint)) -and $fingerprint) {
            $tls.utls.enabled = $true
            $tls.utls.fingerprint = [string]$fingerprint
        }

        $realityOpts = $ProxyData['reality-opts']
        $realityPublicKey = $ProxyData['public-key']
        $realityShortId = $ProxyData['short-id']
        if (-not $realityPublicKey -and $realityOpts) {
            if ($realityOpts -is [hashtable]) {
                $realityPublicKey = $realityOpts['public-key']
                $realityShortId = $realityOpts['short-id']
            }
            else {
                $realityPublicKey = $realityOpts.'public-key'
                $realityShortId = $realityOpts.'short-id'
            }
        }

        if (($ProxyData.reality -eq $true -or $realityOpts) -and $realityPublicKey -and $realityShortId) {
            $tls.reality.enabled = $true
            $tls.reality.public_key = $realityPublicKey
            $tls.reality.short_id = $realityShortId
        }
    }

    return $tls
}

function New-SharedTransportConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$ProxyData
    )

    $transport = [PSCustomObject]@{
        type = $null
        ws   = [PSCustomObject]@{
            path    = $null
            headers = @{}
        }
    }
    if ($ProxyData.network -eq "ws" -and $ProxyData."ws-opts") {
        $wsOpts = $ProxyData."ws-opts"
        $transport.type = "ws"
        $transport.ws.path = $wsOpts.path ?? "/"
        $transport.ws.headers = $wsOpts.headers ?? @{}
    }

    return $transport
}

function Test-RequiredFieldsAndNonEmpty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$ProxyData,

        [Parameter(Mandatory)]
        [string[]]$RequiredFields,

        [Parameter(Mandatory)]
        [string[]]$NonEmptyFields,

        [string]$FieldPrefix = ""
    )

    $errors = @()

    # 检查必填字段存在性
    foreach ($field in $RequiredFields) {
        if (-not $ProxyData.ContainsKey($field)) {
            $errorMsg = if ($FieldPrefix) { "$FieldPrefix 缺少字段: $field" } else { "缺少字段: $field" }
            $errors += $errorMsg
        }
    }

    # 检查字段非空
    foreach ($field in $NonEmptyFields) {
        if ([string]::IsNullOrWhiteSpace($ProxyData[$field])) {
            $errorMsg = if ($FieldPrefix) { "$FieldPrefix 字段 $field 不能为空" } else { "字段 $field 不能为空" }
            $errors += $errorMsg
        }
    }

    return $errors
}
