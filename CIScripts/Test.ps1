Param(
    [Parameter(Mandatory = $true)] [string] $TestReportDir,
    [Parameter(Mandatory = $true)] [string] $TestenvConfFile
)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

$Sessions = New-RemoteSessionsToTestbeds -TestenvConfFile $TestenvConfFile

if (-not (Test-Path $TestReportDir)) {
    New-Item -ItemType Directory -Path $TestReportDir | Out-Null
}

Invoke-IntegrationAndFunctionalTests -Sessions $Sessions `
    -TestenvConfFile $TestenvConfFile `
    -TestReportOutputDirectory $TestReportDir

$Job.Done()
