<#
.SYNOPSIS
ClashToSingBox 单元测试 —— Validator 共享逻辑一致性测试
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '../../Classes/ProxyNode.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validation.Shared.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Vmess.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Shadowsocks.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Trojan.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Vless.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/AnyTls.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validator.ps1')
}

Describe "Validator 共享逻辑一致性测试" {
    It "【TLS】VMess 与 Trojan 解析结果应一致" {
        $sharedTlsInput = @{
            name               = 'node-a'
            server             = 'example.com'
            port               = '443'
            tls                = $true
            sni                = 'sni.example.com'
            'skip-cert-verify' = $true
            utls               = $true
            fingerprint        = 'chrome'
            reality            = $true
            'public-key'       = 'pub-key-123'
            'short-id'         = 'abcd'
        }

        $vmessData = $sharedTlsInput.Clone()
        $vmessData.uuid = '00000000-0000-0000-0000-000000000000'

        $trojanData = $sharedTlsInput.Clone()
        $trojanData.password = 'secret'

        $vmess = Invoke-VmessValidator -ProxyData $vmessData
        $trojan = Invoke-TrojanValidator -ProxyData $trojanData

        $vmess.IsValid | Should -BeTrue
        $trojan.IsValid | Should -BeTrue

        $vmess.Node.Tls.enabled | Should -Be $trojan.Node.Tls.enabled
        $vmess.Node.Tls.server_name | Should -Be $trojan.Node.Tls.server_name
        $vmess.Node.Tls.insecure | Should -Be $trojan.Node.Tls.insecure
        $vmess.Node.Tls.disable_sni | Should -Be $trojan.Node.Tls.disable_sni

        $vmess.Node.Tls.utls.enabled | Should -Be $trojan.Node.Tls.utls.enabled
        $vmess.Node.Tls.utls.fingerprint | Should -Be $trojan.Node.Tls.utls.fingerprint

        $vmess.Node.Tls.reality.enabled | Should -Be $trojan.Node.Tls.reality.enabled
        $vmess.Node.Tls.reality.public_key | Should -Be $trojan.Node.Tls.reality.public_key
        $vmess.Node.Tls.reality.short_id | Should -Be $trojan.Node.Tls.reality.short_id
    }

    It "【WS】VMess 与 Trojan 解析结果应一致" {
        $sharedWsInput = @{
            name      = 'node-ws'
            server    = 'ws.example.com'
            port      = '8443'
            network   = 'ws'
            'ws-opts' = @{
                path    = '/chat'
                headers = @{
                    Host = 'edge.example.com'
                }
            }
        }

        $vmessData = $sharedWsInput.Clone()
        $vmessData.uuid = '11111111-1111-1111-1111-111111111111'

        $trojanData = $sharedWsInput.Clone()
        $trojanData.password = 'secret'

        $vmess = Invoke-VmessValidator -ProxyData $vmessData
        $trojan = Invoke-TrojanValidator -ProxyData $trojanData

        $vmess.IsValid | Should -BeTrue
        $trojan.IsValid | Should -BeTrue

        $vmess.Node.Transport.type | Should -Be 'ws'
        $trojan.Node.Transport.type | Should -Be 'ws'
        $vmess.Node.Transport.ws.path | Should -Be $trojan.Node.Transport.ws.path
        $vmess.Node.Transport.ws.headers.Host | Should -Be $trojan.Node.Transport.ws.headers.Host
    }

    It "【WS early-data】VMess、Trojan 与 VLESS 应共享解析结果" {
        $sharedWsInput = @{
            name      = 'node-early-data'
            server    = 'ws.example.com'
            port      = '8443'
            network   = 'ws'
            'ws-opts' = @{
                path                    = '/chat'
                'max-early-data'        = 2048
                'early-data-header-name' = 'Sec-WebSocket-Protocol'
            }
        }

        $vmessData = $sharedWsInput.Clone()
        $vmessData.uuid = '11111111-1111-1111-1111-111111111111'
        $trojanData = $sharedWsInput.Clone()
        $trojanData.password = 'secret'
        $vlessData = $sharedWsInput.Clone()
        $vlessData.uuid = '22222222-2222-2222-2222-222222222222'

        $results = @(
            Invoke-VmessValidator -ProxyData $vmessData
            Invoke-TrojanValidator -ProxyData $trojanData
            Invoke-VlessValidator -ProxyData $vlessData
        )

        $results.IsValid | Should -Be @( $true, $true, $true )
        foreach ($result in $results) {
            $result.Node.Transport.ws.max_early_data | Should -Be 2048
            $result.Node.Transport.ws.early_data_header_name | Should -Be 'Sec-WebSocket-Protocol'
        }
    }

    It "【WS early-data】非法 max-early-data 应拒绝节点" {
        foreach ($invalidValue in @('-1', '1.5', 'not-a-number')) {
            $proxyData = @{
                name      = 'invalid-early-data'
                server    = 'ws.example.com'
                port      = '443'
                uuid      = '11111111-1111-1111-1111-111111111111'
                network   = 'ws'
                'ws-opts' = @{ 'max-early-data' = $invalidValue }
            }

            $result = Invoke-VmessValidator -ProxyData $proxyData

            $result.IsValid | Should -BeFalse
            $result.Errors | Should -Contain 'ws-opts.max-early-data 必须是大于等于 0 的整数'
        }
    }

    It "【TLS默认】未启用 TLS 时两协议行为一致" {
        $vmessData = @{
            name   = 'vmess-no-tls'
            server = '1.1.1.1'
            port   = '443'
            uuid   = '22222222-2222-2222-2222-222222222222'
        }

        $trojanData = @{
            name     = 'trojan-no-tls'
            server   = '1.1.1.1'
            port     = '443'
            password = 'pwd'
        }

        $vmess = Invoke-VmessValidator -ProxyData $vmessData
        $trojan = Invoke-TrojanValidator -ProxyData $trojanData

        $vmess.IsValid | Should -BeTrue
        $trojan.IsValid | Should -BeTrue

        $vmess.Node.Tls.enabled | Should -BeFalse
        $trojan.Node.Tls.enabled | Should -BeFalse
        $vmess.Node.Tls.IsEmpty() | Should -BeTrue
        $trojan.Node.Tls.IsEmpty() | Should -BeTrue
    }
}
