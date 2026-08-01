Describe 'CI-4 required-check gate validation' {
    It 'intentionally fails before the gate is verified' {
        $false | Should -BeTrue
    }
}
