<#
.SYNOPSIS
ClashToSingBox 单元测试 —— 校验器纯逻辑测试
#>
# Pester 5+ 格式
BeforeAll {
    # 单元测试直接点源类与私有校验函数，避免模块私有作用域限制
    . (Join-Path $PSScriptRoot '../../Classes/ProxyNode.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validation.Shared.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Vmess.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Shadowsocks.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Trojan.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/Vless.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validators/AnyTls.Validator.ps1')
    . (Join-Path $PSScriptRoot '../../Private/Validator.ps1')
}

Describe "VMess 校验器单元测试" {
    It "【正确用例】完整VMess配置 → 校验通过" {
        $proxyData = @{
            name   = "test-vmess"
            server = "1.1.1.1"
            port   = "443"
            uuid   = "00000000-0000-0000-0000-000000000000"
            cipher = "auto"
        }
        $result = Invoke-VmessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Protocol | Should -Be "vmess"
    }

    It "【必填校验】缺少uuid → 校验失败" {
        $proxyData = @{
            name   = "test-vmess"
            server = "1.1.1.1"
            port   = "443"
            # 故意缺 uuid
        }
        $result = Invoke-VmessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $false
        $result.Errors -match "缺少字段: uuid" | Should -Not -Be $null
    }

    It "【非空校验】name为空 → 校验失败" {
        $proxyData = @{
            name   = ""
            server = "1.1.1.1"
            port   = "443"
            uuid   = "00000000-0000-0000-0000-000000000000"
        }
        $result = Invoke-VmessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $false
    }

    It "【端口校验】端口=70000(超出65535) → 校验失败" {
        $proxyData = @{
            name   = "test-vmess"
            server = "1.1.1.1"
            port   = "70000"
            uuid   = "00000000-0000-0000-0000-000000000000"
        }
        $result = Invoke-VmessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $false
    }
}

Describe "SS 校验器单元测试" {
    It "【正确用例】完整SS配置 → 校验通过" {
        $proxyData = @{
            name     = "test-ss"
            server   = "2.2.2.2"
            port     = "8388"
            cipher   = "aes-256-gcm"
            password = "123456"
        }
        $result = Invoke-SsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Protocol | Should -Be "shadowsocks"
    }

    It "【必填校验】缺少password → 校验失败" {
        $proxyData = @{
            name   = "test-ss"
            server = "2.2.2.2"
            port   = "8388"
            cipher = "aes-256-gcm"
            # 缺 password
        }
        $result = Invoke-SsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $false
    }
}

Describe "VLESS 校验器单元测试" {
    It "【正确用例】完整VLESS配置(含flow) → 校验通过" {
        $proxyData = @{
            name   = "test-vless"
            server = "5.5.5.5"
            port   = "443"
            uuid   = "33333333-3333-3333-3333-333333333333"
            flow   = "xtls-rprx-vision"
            tls    = $true
        }
        $result = Invoke-VlessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Protocol | Should -Be "vless"
        $result.Node.Flow | Should -Be "xtls-rprx-vision"
        $result.Node.PacketEncoding | Should -Be ""
    }

    It "【可选字段】不传flow → 校验通过" {
        $proxyData = @{
            name   = "test-vless-no-flow"
            server = "6.6.6.6"
            port   = "8443"
            uuid   = "44444444-4444-4444-4444-444444444444"
        }
        $result = Invoke-VlessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Flow | Should -Be $null
    }

    It "【flow校验】非法flow值 → 校验失败" {
        $proxyData = @{
            name   = "test-vless-invalid-flow"
            server = "7.7.7.7"
            port   = "443"
            uuid   = "55555555-5555-5555-5555-555555555555"
            flow   = "invalid-flow"
        }
        $result = Invoke-VlessValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $false
        $result.Errors -match "VLESS flow 仅支持 xtls-rprx-vision" | Should -Not -BeNullOrEmpty
    }

    It "【主路由】type=vless 时应进入 VLESS 校验器" {
        $proxyData = @{
            type   = "vless"
            name   = "router-vless"
            server = "8.8.8.8"
            port   = "443"
            uuid   = "66666666-6666-6666-6666-666666666666"
            flow   = "xtls-rprx-vision"
        }
        $result = Invoke-Validator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Protocol | Should -Be "vless"
        $result.Node.Flow | Should -Be "xtls-rprx-vision"
    }

    It "【Clash字段映射】servername/client-fingerprint/reality-opts 应映射到 TLS" {
        $proxyData = @{
            name                 = "vless-clash-alias"
            server               = "us1.miyazono-kaori.com"
            port                 = "443"
            uuid                 = "99999999-9999-9999-9999-999999999999"
            flow                 = "xtls-rprx-vision"
            tls                  = $true
            'skip-cert-verify'   = $false
            servername           = "download-porter.hoyoverse.com"
            'client-fingerprint' = "chrome"
            'reality-opts'       = @{
                'public-key' = "MrVc8uqpwhoXwJXD-2rOkZp-gXyIH15mYx0noP7joxM"
                'short-id'   = "014c5bef3f"
            }
        }

        $result = Invoke-VlessValidator -ProxyData $proxyData

        $result.IsValid | Should -Be $true
        $result.Node.Tls.enabled | Should -BeTrue
        $result.Node.Tls.server_name | Should -Be "download-porter.hoyoverse.com"
        $result.Node.Tls.disable_sni | Should -BeFalse
        $result.Node.Tls.insecure | Should -BeFalse

        $result.Node.Tls.utls.enabled | Should -BeTrue
        $result.Node.Tls.utls.fingerprint | Should -Be "chrome"

        $result.Node.Tls.reality.enabled | Should -BeTrue
        $result.Node.Tls.reality.public_key | Should -Be "MrVc8uqpwhoXwJXD-2rOkZp-gXyIH15mYx0noP7joxM"
        $result.Node.Tls.reality.short_id | Should -Be "014c5bef3f"
    }
}

Describe "AnyTLS 校验器单元测试" {
    It "【正确用例】完整AnyTLS配置 → 校验通过" {
        $proxyData = @{
            name     = "test-anytls"
            server   = "9.9.9.9"
            port     = "443"
            password = "abcdefg123456"
            tls      = $true
        }
        $result = Invoke-AnyTlsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Protocol | Should -Be "anytls"
        $result.Node.Password | Should -Be "abcdefg123456"
    }

    It "【必填校验】缺少password → 校验失败" {
        $proxyData = @{
            name   = "test-anytls-no-pwd"
            server = "10.10.10.10"
            port   = "443"
            # 缺 password
            tls    = $true
        }
        $result = Invoke-AnyTlsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $false
        $result.Errors -match "缺少字段: password" | Should -Not -Be $null
    }

    It "【默认TLS】不指定tls参数 → TLS默认启用" {
        $proxyData = @{
            name     = "test-anytls-no-tls-param"
            server   = "11.11.11.11"
            port     = "443"
            password = "pwd123"
            # 不指定 tls 参数，默认应启用
        }
        $result = Invoke-AnyTlsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        # TLS 应默认启用（在 New-SharedTlsConfig 中处理）
        $result.Node.Tls.enabled | Should -BeTrue
    }

    It "【独有字段】idle_session_check_interval 应被解析" {
        $proxyData = @{
            name                           = "test-anytls-idle"
            server                         = "12.12.12.12"
            port                           = "443"
            password                       = "pwd123"
            tls                            = $true
            'idle_session_check_interval'  = "60s"
            'idle_session_timeout'         = "120s"
            'min_idle_session'             = 3
        }
        $result = Invoke-AnyTlsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.AnyTls.idle_session_check_interval | Should -Be "60s"
        $result.Node.AnyTls.idle_session_timeout | Should -Be "120s"
        $result.Node.AnyTls.min_idle_session | Should -Be 3
    }

    It "【独有字段】缺少idle参数 → 使用默认值" {
        $proxyData = @{
            name     = "test-anytls-default-idle"
            server   = "13.13.13.13"
            port     = "443"
            password = "pwd123"
            tls      = $true
            # 不设置 idle 参数
        }
        $result = Invoke-AnyTlsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.AnyTls.idle_session_check_interval | Should -Be "30s"
        $result.Node.AnyTls.idle_session_timeout | Should -Be "30s"
        $result.Node.AnyTls.min_idle_session | Should -Be 0
    }

    It "【主路由】type=anytls 时应进入 AnyTLS 校验器" {
        $proxyData = @{
            type     = "anytls"
            name     = "router-anytls"
            server   = "14.14.14.14"
            port     = "443"
            password = "pwd123"
            tls      = $true
        }
        $result = Invoke-Validator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Protocol | Should -Be "anytls"
    }

    It "【TLS字段映射】servername/skip-cert-verify 应正确映射到 AnyTLS 的 TLS" {
        $proxyData = @{
            name               = "anytls-with-tls"
            server             = "tls.example.com"
            port               = "443"
            password           = "pwd123"
            tls                = $true
            'skip-cert-verify' = $true
            servername         = "example.com"
        }
        $result = Invoke-AnyTlsValidator -ProxyData $proxyData
        $result.IsValid | Should -Be $true
        $result.Node.Tls.enabled | Should -BeTrue
        $result.Node.Tls.server_name | Should -Be "example.com"
        $result.Node.Tls.insecure | Should -BeTrue
    }
}

Describe "公共功能 - 名称过滤" {
    It "【Filter】名称包含test → 被过滤" {
        $proxyData = @{
            name   = "test-vmess"
            server = "1.1.1.1"
            port   = "443"
            uuid   = "00000000-0000-0000-0000-000000000000"
        }
        $result = Invoke-VmessValidator -ProxyData $proxyData -Filter "test"
        $result.IsFiltered | Should -Be $true
    }
}
