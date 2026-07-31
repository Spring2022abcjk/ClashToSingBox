<#
.SYNOPSIS
将 ProxyNode 转为 sing-box 配置
#>
function Invoke-Converter {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Node
    )

    process {
        # ======================
        # 共用基础结构
        # ======================
        $outbound = [ordered]@{
            type        = $Node.Protocol
            tag         = $Node.Tag
            server      = $Node.Server
            server_port = $Node.ServerPort
        }
        # ======================
        # 公共 Tls
        # ======================
        $tlsSupportedProtos = @("vmess", "trojan", "vless", "anytls")
        $proto = $Node.Protocol
        if ($tlsSupportedProtos -contains $proto -and $Node.Tls -and -not $Node.Tls.IsEmpty()) {
            $tlsOut = [ordered]@{ enabled = $Node.Tls.enabled }
            if ($Node.Tls.disable_sni) { $tlsOut.disable_sni = $true }
            if ($Node.Tls.server_name) { $tlsOut.server_name = $Node.Tls.server_name }
            if ($Node.Tls.insecure) { $tlsOut.insecure = $true }

            if ($Node.Tls.utls -and -not $Node.Tls.utls.IsEmpty()) {
                $tlsOut.utls = @{
                    enabled     = $Node.Tls.utls.enabled
                    fingerprint = $Node.Tls.utls.fingerprint
                }
            }
            if ($Node.Tls.reality -and -not $Node.Tls.reality.IsEmpty()) {
                $tlsOut.reality = @{
                    enabled    = $Node.Tls.reality.enabled
                    public_key = $Node.Tls.reality.public_key
                    short_id   = $Node.Tls.reality.short_id
                }
            }
            $outbound.tls = $tlsOut
        }

        # ======================
        # 公共 Transport
        # ======================
        $transportSupportedProtos = @("vmess", "trojan", "vless")
        if ($transportSupportedProtos -contains $proto -and $Node.Transport -and $Node.Transport.type -eq "ws") {
            $transportOut = [ordered]@{
                type = "ws"
            }
            # 现阶段只实现 path + headers
            if ($Node.Transport.ws.path) {
                $transportOut.path = $Node.Transport.ws.path
            }
            if ($Node.Transport.ws.headers -and $Node.Transport.ws.headers.Count -gt 0) {
                $transportOut.headers = $Node.Transport.ws.headers
            }
            # 计划中：max_early_data / early_data_header_name
            $outbound.transport = $transportOut
        }
        # ======================
        # 3. 公共 Multiplex
        # ======================
        $multiplexSupportedProtos = @("vmess", "shadowsocks", "trojan", "vless")
        if ($multiplexSupportedProtos -contains $proto -and $Node.Multiplex -and !$Node.Multiplex.IsEmpty()) {
            $mul = $Node.Multiplex
            $multiplexOut = [ordered]@{
                enabled = $mul.enabled
            }
            if ($mul.protocol) { $multiplexOut.protocol = $mul.protocol }
            if ($mul.max_connections -gt 0) { $multiplexOut.max_connections = $mul.max_connections }
            if ($mul.min_streams -gt 0) { $multiplexOut.min_streams = $mul.min_streams }
            # ...未来再加字段
            $outbound.multiplex = $multiplexOut
        }

        switch ($Node.Protocol) {
            "vmess" {
                $outbound.uuid = $Node.Uuid
                $outbound.security = $Node.Security
                $outbound.alter_id = $Node.AlterId
                $outbound.global_padding = $Node.GlobalPadding
                $outbound.authenticated_length = $Node.AuthenticatedLength
                break
            }
            "shadowsocks" {
                $outbound.method = $Node.method
                $outbound.password = $Node.password
                $outbound.udp_over_tcp = $false  # 占位
                break
            }
            # 以后加协议只需要在这里加 case
            "vless" {
                $outbound.uuid = $Node.Uuid
                if ($Node.Flow) {
                    $outbound.flow = $Node.Flow
                }
                $outbound.packet_encoding = ($Node.PacketEncoding ?? "")
                break
            }
            "trojan" {
                $outbound.password = $Node.Password
                break
            }
            "anytls" {
                $outbound.password = $Node.Password
                # AnyTLS 独有字段
                if ($Node.AnyTls) {
                    if ($Node.AnyTls.idle_session_check_interval) {
                        $outbound.idle_session_check_interval = $Node.AnyTls.idle_session_check_interval
                    }
                    if ($Node.AnyTls.idle_session_timeout) {
                        $outbound.idle_session_timeout = $Node.AnyTls.idle_session_timeout
                    }
                    if ($Node.AnyTls.min_idle_session -gt 0) {
                        $outbound.min_idle_session = $Node.AnyTls.min_idle_session
                    }
                }
                break
            }
        }

        return $outbound
    }
}
