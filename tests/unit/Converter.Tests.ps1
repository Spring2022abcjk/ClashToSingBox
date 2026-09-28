<#
.SYNOPSIS
ClashToSingBox 单元测试 —— Converter 逻辑测试
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '../../Classes/ProxyNode.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Converter.ps1')
}

Describe "Converter 单元测试" {
    It "【VMess】应输出协议私有字段" {
        $node = [PSCustomObject]@{
            Protocol            = 'vmess'
            Tag                 = 'vmess-node'
            Server              = '1.1.1.1'
            ServerPort          = 443
            Uuid                = '00000000-0000-0000-0000-000000000000'
            Security            = 'auto'
            AlterId             = 0
            GlobalPadding       = $false
            AuthenticatedLength = $true
            Tls                 = [TlsConfig]::new()
            Transport           = [TransportConfig]::new()
            Multiplex           = [MultiplexConfig]::new()
        }

        $outbound = $node | Invoke-Converter

        $outbound.type | Should -Be 'vmess'
        $outbound.uuid | Should -Be '00000000-0000-0000-0000-000000000000'
        $outbound.security | Should -Be 'auto'
        $outbound.alter_id | Should -Be 0
        $outbound.global_padding | Should -BeFalse
        $outbound.authenticated_length | Should -BeTrue
    }

    It "【Multiplex】min_streams 应正确映射" {
        $mul = [MultiplexConfig]::new()
        $mul.enabled = $true
        $mul.min_streams = 3

        $node = [PSCustomObject]@{
            Protocol            = 'vmess'
            Tag                 = 'vmess-mux'
            Server              = '2.2.2.2'
            ServerPort          = 8443
            Uuid                = '11111111-1111-1111-1111-111111111111'
            Security            = 'auto'
            AlterId             = 0
            GlobalPadding       = $false
            AuthenticatedLength = $true
            Tls                 = [TlsConfig]::new()
            Transport           = [TransportConfig]::new()
            Multiplex           = $mul
        }

        $outbound = $node | Invoke-Converter

        $outbound.multiplex.enabled | Should -BeTrue
        $outbound.multiplex.min_streams | Should -Be 3
    }

    It "【Multiplex】协议分支不应覆盖公共层稀疏输出" {
        $mul = [MultiplexConfig]::new()
        $mul.enabled = $true
        $mul.min_streams = 2

        $node = [PSCustomObject]@{
            Protocol            = 'trojan'
            Tag                 = 'trojan-mux'
            Server              = '3.3.3.3'
            ServerPort          = 443
            Password            = 'pwd'
            Tls                 = [TlsConfig]::new()
            Transport           = [TransportConfig]::new()
            Multiplex           = $mul
        }

        $outbound = $node | Invoke-Converter

        $outbound.password | Should -Be 'pwd'
        $outbound.multiplex.enabled | Should -BeTrue
        $outbound.multiplex.min_streams | Should -Be 2

        # 稀疏输出：未设置的字段不应出现
        $outbound.multiplex.Contains('max_streams') | Should -BeFalse
        $outbound.multiplex.Contains('padding') | Should -BeFalse
    }

    It "【Shadowsocks】应保留协议字段并复用公共 multiplex" {
        $mul = [MultiplexConfig]::new()
        $mul.enabled = $true
        $mul.protocol = 'smux'

        $node = [PSCustomObject]@{
            Protocol   = 'shadowsocks'
            Tag        = 'ss-node'
            Server     = '4.4.4.4'
            ServerPort = 8388
            Method     = 'aes-256-gcm'
            Password   = 'secret'
            Multiplex  = $mul
        }

        $outbound = $node | Invoke-Converter

        $outbound.type | Should -Be 'shadowsocks'
        $outbound.method | Should -Be 'aes-256-gcm'
        $outbound.password | Should -Be 'secret'
        $outbound.udp_over_tcp | Should -BeFalse
        $outbound.multiplex.enabled | Should -BeTrue
        $outbound.multiplex.protocol | Should -Be 'smux'
    }

    It "【VLESS】应输出 flow/packet_encoding 并复用公共 TLS/Transport/Multiplex" {
        $tls = [TlsConfig]::new()
        $tls.enabled = $true
        $tls.server_name = 'vless.example.com'
        $tls.insecure = $true

        $transport = [TransportConfig]::new()
        $transport.type = 'ws'
        $transport.ws.path = '/vless'
        $transport.ws.headers = @{ Host = 'edge.vless.example.com' }

        $mul = [MultiplexConfig]::new()
        $mul.enabled = $true
        $mul.min_streams = 4

        $node = [PSCustomObject]@{
            Protocol       = 'vless'
            Tag            = 'vless-node'
            Server         = '9.9.9.9'
            ServerPort     = 443
            Uuid           = '77777777-7777-7777-7777-777777777777'
            Flow           = 'xtls-rprx-vision'
            PacketEncoding = ''
            Tls            = $tls
            Transport      = $transport
            Multiplex      = $mul
        }

        $outbound = $node | Invoke-Converter

        $outbound.type | Should -Be 'vless'
        $outbound.uuid | Should -Be '77777777-7777-7777-7777-777777777777'
        $outbound.flow | Should -Be 'xtls-rprx-vision'
        $outbound.packet_encoding | Should -Be ''
        $outbound.tls.enabled | Should -BeTrue
        $outbound.tls.server_name | Should -Be 'vless.example.com'
        $outbound.tls.insecure | Should -BeTrue
        $outbound.transport.type | Should -Be 'ws'
        $outbound.transport.path | Should -Be '/vless'
        $outbound.transport.headers.Host | Should -Be 'edge.vless.example.com'
        $outbound.multiplex.enabled | Should -BeTrue
        $outbound.multiplex.min_streams | Should -Be 4
    }

    It "【WebSocket early-data】应稀疏输出 early-data 字段" {
        $transport = [TransportConfig]::new()
        $transport.type = 'ws'
        $transport.ws.path = '/early'
        $transport.ws.max_early_data = 2048
        $transport.ws.early_data_header_name = 'Sec-WebSocket-Protocol'

        $node = [PSCustomObject]@{
            Protocol   = 'vmess'
            Tag        = 'vmess-early-data'
            Server     = '5.5.5.5'
            ServerPort = 443
            Uuid       = '33333333-3333-3333-3333-333333333333'
            Security   = 'auto'
            AlterId    = 0
            Tls        = [TlsConfig]::new()
            Transport  = $transport
            Multiplex  = [MultiplexConfig]::new()
        }

        $outbound = $node | Invoke-Converter

        $outbound.transport.max_early_data | Should -Be 2048
        $outbound.transport.early_data_header_name | Should -Be 'Sec-WebSocket-Protocol'
    }

    It "【WebSocket early-data】默认值不应输出" {
        $transport = [TransportConfig]::new()
        $transport.type = 'ws'
        $transport.ws.path = '/default'

        $node = [PSCustomObject]@{
            Protocol   = 'vless'
            Tag        = 'vless-default-early-data'
            Server     = '6.6.6.6'
            ServerPort = 443
            Uuid       = '44444444-4444-4444-4444-444444444444'
            Tls        = [TlsConfig]::new()
            Transport  = $transport
            Multiplex  = [MultiplexConfig]::new()
        }

        $outbound = $node | Invoke-Converter

        $outbound.transport.Contains('max_early_data') | Should -BeFalse
        $outbound.transport.Contains('early_data_header_name') | Should -BeFalse
    }

    It "【AnyTLS】应输出协议必填字段和独有字段" {
        $anyTls = [AnyTlsConfig]::new()
        $anyTls.idle_session_check_interval = "60s"
        $anyTls.idle_session_timeout = "120s"
        $anyTls.min_idle_session = 5

        $tls = [TlsConfig]::new()
        $tls.enabled = $true
        $tls.server_name = "anytls.example.com"

        $node = [PSCustomObject]@{
            Protocol   = 'anytls'
            Tag        = 'anytls-node'
            Server     = '88.88.88.88'
            ServerPort = 443
            Password   = 'anytls-password'
            Tls        = $tls
            AnyTls     = $anyTls
        }

        $outbound = $node | Invoke-Converter

        $outbound.type | Should -Be 'anytls'
        $outbound.password | Should -Be 'anytls-password'
        $outbound.tls.enabled | Should -BeTrue
        $outbound.tls.server_name | Should -Be 'anytls.example.com'
        $outbound.idle_session_check_interval | Should -Be '60s'
        $outbound.idle_session_timeout | Should -Be '120s'
        $outbound.min_idle_session | Should -Be 5
    }

    It "【AnyTLS】默认idle参数不应输出(或保留默认值)" {
        $anyTls = [AnyTlsConfig]::new()
        # 使用默认值，未修改

        $tls = [TlsConfig]::new()
        $tls.enabled = $true

        $node = [PSCustomObject]@{
            Protocol   = 'anytls'
            Tag        = 'anytls-default'
            Server     = '99.99.99.99'
            ServerPort = 443
            Password   = 'pwd'
            Tls        = $tls
            AnyTls     = $anyTls
        }

        $outbound = $node | Invoke-Converter

        $outbound.type | Should -Be 'anytls'
        $outbound.password | Should -Be 'pwd'
        # 验证默认值被正确输出
        $outbound.idle_session_check_interval | Should -Be '30s'
        $outbound.idle_session_timeout | Should -Be '30s'
        # min_idle_session 为 0，不应输出
        $outbound.Contains('min_idle_session') | Should -BeFalse
    }
}
