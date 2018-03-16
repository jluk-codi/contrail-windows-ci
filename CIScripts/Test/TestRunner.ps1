. $PSScriptRoot\TestConfigurationUtils.ps1
. $PSScriptRoot\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1

function Invoke-TestScenarios {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $TestsBlacklist = @(
        # Put filenames of blacklisted tests here.
    )

    $TestPaths = Get-ChildItem -Recurse -Filter "*.Tests.ps1"
    $WhitelistedTestPaths = $TestPaths | Where-Object { !($_.Name -in $TestsBlacklist) }
    $PesterScripts = $WhitelistedTestPaths | ForEach-Object {
        @{
            Path=$_.FullName;
            Parameters= @{
                TestenvConfFile=$TestenvConfFile
                ConfigFile=$TestConfigurationFile
            }; 
            Arguments=@()
        }
    }
    $TestReportOutputPath = "$TestReportOutputDirectory\testReport.xml"
    $Results = Invoke-Pester -PassThru -Script $PesterScripts `
        -OutputFormat NUnitXml -OutputFile $TestReportOutputPath
    Write-Host "Number of passed tests: $($Results.PassedCount)"
    Write-Host "Number of failed tests: $($Results.FailedCount)"
    Write-Host "Report written to $TestReportOutputPath"
    if ($Results.FailedCount -gt 0) {
        throw "Some tests failed"
    }
}

function Get-Logs {
    Param ([Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions)

    foreach ($Session in $Sessions) {
        if ($Session.State -eq "Opened") {
            Write-Host
            Write-Host "Displaying logs from $($Session.ComputerName)"

            Invoke-Command -Session $Session {
                $LogPaths = @(
                    "$Env:ProgramData/ContrailDockerDriver/log.txt",
                    "$Env:ProgramData/ContrailDockerDriver/log.old.txt"
                )

                foreach ($Path in $LogPaths) {
                    if (Test-Path $Path) {
                        Write-Host
                        Write-Host "Contents of ${Path}:"
                        Get-Content $Path
                    }
                }
            }
        }
    }
}

function Invoke-IntegrationAndFunctionalTests {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT[]] $Sessions,
        [Parameter(Mandatory = $true)] [String] $TestenvConfFile,
        [Parameter(Mandatory = $true)] [String] $TestConfigurationFile,
        [Parameter(Mandatory = $true)] [String] $TestReportOutputDirectory
    )

    $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
    $ContrailNM = [ContrailNetworkManager]::new($ControllerConfig)
    $ContrailNM.AddProject($null)

    Invoke-TestScenarios -Sessions $Sessions `
        -TestenvConfFile $TestenvConfFile `
        -TestConfigurationFile $TestConfigurationFile `
        -TestReportOutputDirectory $TestReportOutputDirectory
}
