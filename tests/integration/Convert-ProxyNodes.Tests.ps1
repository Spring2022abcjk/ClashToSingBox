BeforeAll {
    $script:ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $script:ModuleManifest = Join-Path $script:ProjectRoot 'ClashToSingBox.psd1'
    $script:InputFile = Join-Path $script:ProjectRoot 'test-inputs/integration-all-protocols.yml'
    $script:ExpectedOutputFile = Join-Path $script:ProjectRoot 'test-outputs/integration-all-protocols-outbounds.json'

    Import-Module $script:ModuleManifest -Force

    function ConvertTo-StableObject {
        param (
            [AllowNull()]
            [object]$Value
        )

        if ($null -eq $Value) {
            return $null
        }

        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [pscustomobject]) {
            return @($Value | ForEach-Object { ConvertTo-StableObject -Value $_ })
        }

        if ($Value -is [pscustomobject]) {
            $stable = [ordered]@{}
            foreach ($property in @($Value.PSObject.Properties.Name | Sort-Object)) {
                $stable[$property] = ConvertTo-StableObject -Value $Value.$property
            }
            return $stable
        }

        return $Value
    }

    function ConvertTo-NormalizedJson {
        param (
            [Parameter(Mandatory, ValueFromPipeline)]
            [string]$Json
        )

        process {
            $parsed = $Json | ConvertFrom-Json
            ConvertTo-StableObject -Value $parsed | ConvertTo-Json -Depth 20 -Compress
        }
    }
}

Describe 'Convert-ProxyNodes integration' {
    It 'converts all supported protocols through the public module command' {
        $outputFile = Join-Path $TestDrive 'integration-outbounds.json'

        $result = Convert-ProxyNodes -InputFile $script:InputFile -OutputFile $outputFile

        $result.Success | Should -BeTrue
        $result.TotalCount | Should -Be 5
        $result.SuccessCount | Should -Be 5
        $result.FilteredCount | Should -Be 0
        $result.FailedCount | Should -Be 0
        $result.Errors | Should -BeNullOrEmpty
        $result.ProtocolCounts['vmess'] | Should -Be 1
        $result.ProtocolCounts['shadowsocks'] | Should -Be 1
        $result.ProtocolCounts['trojan'] | Should -Be 1
        $result.ProtocolCounts['vless'] | Should -Be 1
        $result.ProtocolCounts['anytls'] | Should -Be 1
        Test-Path $outputFile | Should -BeTrue

        $actualJson = Get-Content -Path $outputFile -Raw -Encoding UTF8
        $expectedJson = Get-Content -Path $script:ExpectedOutputFile -Raw -Encoding UTF8
        ($actualJson | ConvertTo-NormalizedJson) | Should -Be ($expectedJson | ConvertTo-NormalizedJson)
    }

    It 'exports the outbound tag list to an explicit output path' {
        $outputFile = Join-Path $TestDrive 'integration-outbounds.json'
        $listFile = Join-Path $TestDrive 'integration-outbound-list.json'

        $result = Convert-ProxyNodes -InputFile $script:InputFile -OutputFile $outputFile -ExportOutboundList -OutboundListOutputPath $listFile

        $result.Success | Should -BeTrue
        Test-Path $listFile | Should -BeTrue

        $list = Get-Content -Path $listFile -Raw -Encoding UTF8 | ConvertFrom-Json
        @($list.outbounds) | Should -Be @(
            'integration-vmess',
            'integration-ss',
            'integration-trojan',
            'integration-vless',
            'integration-anytls'
        )
    }

    It 'exports the outbound tag list to the default path when no explicit path is provided' {
        $outputFile = Join-Path $TestDrive 'default-list-outbounds.json'
        $expectedListFile = Join-Path $TestDrive 'default-list-outbounds.outbound_list.json'

        $result = Convert-ProxyNodes -InputFile $script:InputFile -OutputFile $outputFile -ExportOutboundList

        $result.Success | Should -BeTrue
        Test-Path $outputFile | Should -BeTrue
        Test-Path $expectedListFile | Should -BeTrue

        $list = Get-Content -Path $expectedListFile -Raw -Encoding UTF8 | ConvertFrom-Json
        @($list.outbounds) | Should -Be @(
            'integration-vmess',
            'integration-ss',
            'integration-trojan',
            'integration-vless',
            'integration-anytls'
        )
    }

    It 'does not emit WebSocket transport for Shadowsocks nodes' {
        $inputFile = Join-Path $TestDrive 'ss-ws.yml'
        $outputFile = Join-Path $TestDrive 'ss-ws-outbounds.json'
        @'
proxies:
  - name: ss-with-ws
    type: ss
    server: ss.example.com
    port: 8388
    cipher: aes-256-gcm
    password: ss-password
    network: ws
    ws-opts:
      path: /ss
      headers:
        Host: edge.ss.example.com
'@ | Set-Content -Path $inputFile -Encoding UTF8NoBOM

        $result = Convert-ProxyNodes -InputFile $inputFile -OutputFile $outputFile

        $result.Success | Should -BeTrue
        $outbound = Get-Content -Path $outputFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $outbound.type | Should -Be 'shadowsocks'
        $outbound.PSObject.Properties.Name | Should -Not -Contain 'transport'
    }

    It 'filters matching nodes and writes only unfiltered outbounds' {
        $outputFile = Join-Path $TestDrive 'filtered-outbounds.json'

        $result = Convert-ProxyNodes -InputFile $script:InputFile -OutputFile $outputFile -Filter 'integration-vmess', 'integration-anytls'

        $result.Success | Should -BeTrue
        $result.TotalCount | Should -Be 5
        $result.SuccessCount | Should -Be 3
        $result.FilteredCount | Should -Be 2
        $result.FailedCount | Should -Be 0
        Test-Path $outputFile | Should -BeTrue

        $outbounds = @(Get-Content -Path $outputFile -Raw -Encoding UTF8 | ConvertFrom-Json)
        $outbounds.tag | Should -Be @(
            'integration-ss',
            'integration-trojan',
            'integration-vless'
        )
    }

    It 'returns a failed result when all nodes are filtered' {
        $outputFile = Join-Path $TestDrive 'all-filtered-outbounds.json'

        $result = Convert-ProxyNodes -InputFile $script:InputFile -OutputFile $outputFile -Filter 'integration-'

        $result.Success | Should -BeFalse
        $result.TotalCount | Should -Be 5
        $result.SuccessCount | Should -Be 0
        $result.FilteredCount | Should -Be 5
        $result.FailedCount | Should -Be 0
        $result.Errors | Should -Contain '没有可转换的节点'
        Test-Path $outputFile | Should -BeFalse
    }

    It 'returns a failed result when every node fails validation' {
        $inputFile = Join-Path $TestDrive 'invalid-proxies.yml'
        $outputFile = Join-Path $TestDrive 'invalid-outbounds.json'
        @'
proxies:
  - name: invalid-vmess
    type: vmess
    server: invalid.example.com
    port: 443

  - name: invalid-ss
    type: ss
    server: invalid.example.com
    port: 8388
    cipher: aes-256-gcm
'@ | Set-Content -Path $inputFile -Encoding UTF8NoBOM

        $result = Convert-ProxyNodes -InputFile $inputFile -OutputFile $outputFile

        $result.Success | Should -BeFalse
        $result.TotalCount | Should -Be 2
        $result.SuccessCount | Should -Be 0
        $result.FilteredCount | Should -Be 0
        $result.FailedCount | Should -Be 2
        $result.Errors | Should -Contain '缺少字段: uuid'
        $result.Errors | Should -Contain 'SS 缺少字段: password'
        $result.Errors | Should -Contain '没有可转换的节点'
        Test-Path $outputFile | Should -BeFalse
    }

    It 'returns a failed result when the input file does not exist' {
        $missingInput = Join-Path $TestDrive 'missing.yml'
        $outputFile = Join-Path $TestDrive 'missing-outbounds.json'

        $result = Convert-ProxyNodes -InputFile $missingInput -OutputFile $outputFile

        $result.Success | Should -BeFalse
        $result.Errors | Should -Not -BeNullOrEmpty
        ($result.Errors -join "`n") | Should -Match '输入文件不存在'
        Test-Path $outputFile | Should -BeFalse
    }
}
