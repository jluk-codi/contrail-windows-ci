Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot/Invoke-CommandWithFunctions.ps1
. $PSScriptRoot/Init.ps1
. $PSScriptRoot/../Testenv/Testenv.ps1
. $PSScriptRoot/../Testenv/Testbed.ps1

Describe "Invoke-CommandWithFunctions tests" {
    function Test-SimpleFunction{
        param(
            [Parameter(Mandatory=$false)] [string] $SimpleParam = "A simple string to return"
        )
        $SimpleParam
    }
    $TestSimpleFunctionInvoked = @(@{
        Name = "Test-SimpleFunction";
        Body = ${Function:Test-SimpleFunction}
    })

    Context "Incorrect function usage handling" {
        It "throws on nonexisting function" {
            { Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestSimpleFunctionInvoked  `
                -ScriptBlock { Test-ANonExistingFunction } } | Should Throw
        }

        It "throws on invoking with incorrectly passed parameter" {
            { Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestSimpleFunctionInvoked  `
                -ScriptBlock { Test-SimpleFunction -InvalidParam $true } } | Should Throw
        }
    }

    Context "correctly defined simple functions" {
        It "invokes function passed in ScriptBlock" {
            Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestSimpleFunctionInvoked `
                -ScriptBlock { Test-SimpleFunction } `
                -CaptureOutput | Should Be "A simple string to return"
        }

        It "correctly gathers output" {
            $str = "A simple string to return"
            Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestSimpleFunctionInvoked  `
                -ScriptBlock { $Using:str } `
                -CaptureOutput  | Should Be $str
        }

        It "correctly passes parameters" {
            $TestSimpleFunctionInvoked = @{
                Name = "Test-SimpleFunction";
                Body = ${Function:Test-SimpleFunction}
            }
            Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestSimpleFunctionInvoked `
                -ScriptBlock {$a = "abcd"; Test-SimpleFunction -SimpleParam $a } `
                -CaptureOutput | Should Be "abcd"
        }
    }

    Context "function invoking another function" {
        function Test-OuterFunction {
            param([Parameter(Mandatory=$true)] [string] $TestString)
                    Test-InnerFunction -ScriptBlock { $TestString }
                }
        $TestOuterFunctionInvoked = @( 
            @{ Name = "Test-OuterFunction"; Body = ${Function:Test-OuterFunction} }
        )

        It "Inner function calls passed string as scriptblock and outputs result" {
            function Test-InnerFunction {
                param([Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock) {
                        Invoke-Expression -Command $ScriptBlock
                    }
                }
            $TestFunctionsInvoked = $TestOuterFunctionInvoked 
            $TestFunctionsInvoked += @{  
                Name = "Test-InnerFunction"; Body = ${Function:Test-InnerFunction} }
            Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestFunctionsInvoked  `
                -ScriptBlock { Test-OuterFunction -TestString "whoami.exe" } `
                -CaptureOutput | Should Not BeNullOrEmpty
        }

        It "allows to throw exception" {
            function Test-InnerFunction {
                param([Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock) {
                        throw "threw"
                    }
                }
            $TestFunctionsInvoked = $TestOuterFunctionInvoked 
            $TestFunctionsInvoked += @{  
                Name = "Test-InnerFunction"; Body = ${Function:Test-InnerFunction } }
            { Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $TestFunctionsInvoked  `
                -ScriptBlock { Test-OuterFunction -TestString "" } } | Should Throw
        }
        It "works with pipelines" {
            function Test-PipelineFunction {
                param([Parameter(ValueFromPipeline=$true)] $notUsed) 
                Process { Test-SimpleFunction -SimpleParam $_ }
            }
            $PipelineInvoked = $TestSimpleFunctionInvoked
            $PipelineInvoked += @{  
                Name = "Test-PipelineFunction";Body = ${Function:Test-PipelineFunction} }
            Invoke-CommandWithFunctions -Session $Session `
                -FunctionsInvoked $PipelineInvoked  `
                -ScriptBlock { 1..5 | Test-PipelineFunction } `
                -CaptureOutput | Should Be @('1', '2', '3', '4', '5')
        }
    }

    BeforeAll {
        $Testbed = (Read-TestbedsConfig -Path $TestenvConfFile)[0]
        $Sessions = New-RemoteSessions -VMs $Testbed
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments", "Session",
            Justification="Analyzer doesn't understand relation of Pester blocks"
        )]
        $Session = $Sessions[0]
    }
}
