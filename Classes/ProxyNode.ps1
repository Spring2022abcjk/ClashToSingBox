# ==============================
 # 【Shared】Multiplex 配置
 # ==============================
 class MultiplexConfig {
     [bool]$enabled = $false
     [string]$protocol = $null
     [int]$max_connections = 0
     [int]$min_streams = 0
     [int]$max_streams = 0
     [bool]$padding = $false
     # 未来可加：brutal
     MultiplexConfig() {
     }
     [bool] IsEmpty() {
         return !$this.enabled
     }
 }

# ==============================
 # 【Shared】WebSocket 配置（目前实现 path + headers）
 # ==============================
 class WsTransportConfig {
     [string]$path = $null
     [hashtable]$headers = @{}
     # 计划中：max_early_data
     # 计划中：early_data_header_name
     [bool] IsEmpty() {
         return [string]::IsNullOrEmpty($this.path) -and $this.headers.Count -eq 0
     }
 }

 # ==============================
 # 【Shared】transport配置
 # ==============================
 class TransportConfig {
     [string]$type = $null # 目前只支持 "ws"
     [WsTransportConfig]$ws
     TransportConfig() {
         $this.ws = [WsTransportConfig]::new()
     }
     [bool] IsEmpty() {
         return [string]::IsNullOrEmpty($this.type) -or $this.ws.IsEmpty()
     }
 }

# ==============================
# 【Shared】uTLS 配置
# ==============================
class UtlsConfig {
    [bool]$enabled = $false
    [string]$fingerprint = $null
    [bool] IsEmpty() {
        return (-not $this.enabled) -or [string]::IsNullOrEmpty($this.fingerprint)
    }
}

# ==============================
# 【Shared】REALITY 配置
# ==============================
class RealityConfig {
    [bool]$enabled = $false
    [string]$public_key = $null
    [string]$short_id = $null
    [bool] IsEmpty() {
        return (-not $this.enabled) -or [string]::IsNullOrEmpty($this.public_key)
    }
}

# ==============================
# 【Shared】TLS 配置（精选实用字段，不做冗余）
# ==============================
class TlsConfig {
    [bool]$enabled = $false
    [bool]$disable_sni = $false
    [string]$server_name = $null
    [bool]$insecure = $false
    [string[]]$alpn = @()
    [string]$min_version = $null
    [UtlsConfig]$utls
    [RealityConfig]$reality
    TlsConfig() {
        $this.utls = [UtlsConfig]::new()
        $this.reality = [RealityConfig]::new()
    }
    [bool] IsEmpty() {
        return (-not $this.enabled)
    }
}

# ==============================
# 【AnyTLS】独有配置
# ==============================
class AnyTlsConfig {
    [string]$idle_session_check_interval = "30s"
    [string]$idle_session_timeout = "30s"
    [int]$min_idle_session = 0
    [bool] IsEmpty() {
        return $false  # AnyTLS 字段均有默认值，不视为空
    }
}

# ==============================
# 基类：所有协议共享（sing-box shared）
# ==============================
class ProxyNode {
    [string]$Protocol
    [string]$Tag

    [string]$Server
    [int]$ServerPort

    [TlsConfig]$Tls
    [TransportConfig]$Transport
    [MultiplexConfig]$Multiplex
    [AnyTlsConfig]$AnyTls

    [bool]$IsValid
    [string[]]$Errors

    ProxyNode() {
        $this.IsValid = $false
        $this.Errors = @()
        $this.Tls = [TlsConfig]::new()
        $this.Transport = [TransportConfig]::new()
        $this.Multiplex = [MultiplexConfig]::new()
        $this.AnyTls = [AnyTlsConfig]::new()
    }
}

# ==============================
# 转换结果类
# ==============================
class ConversionResult {
    [bool]$Success
    [int]$TotalCount
    [int]$SuccessCount
    [int]$FilteredCount
    [int]$FailedCount
    [hashtable]$ProtocolCounts
    [object[]]$Outbounds
    [string[]]$Errors
    [datetime]$StartTime
    [datetime]$EndTime
    [timespan]$Duration
    ConversionResult() {
        $this.Success = $false
        $this.TotalCount = 0
        $this.SuccessCount = 0
        $this.FilteredCount = 0
        $this.FailedCount = 0
        $this.ProtocolCounts = @{}
        $this.Outbounds = @()
        $this.Errors = @()
        $this.Duration = [timespan]::Zero
    }
}
