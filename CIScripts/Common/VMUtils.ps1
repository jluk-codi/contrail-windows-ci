. $PSScriptRoot\Aliases.ps1
. $PSScriptRoot\..\Testenv\Testenv.ps1

function Get-TestbedCredential {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText",
        "", Justification="This are just credentials to a testbed VM.")]
    Param ([Parameter(Mandatory = $true)] [Hashtable] $VM)

    if (-not $VM['Username'] -and -not $VM['Password']) {
        return Get-Credential # assume interactive mode
    } else {
        $VMUsername = Get-UsernameInWorkgroup -Username $VM.Username
        $VMPassword = $VM.Password | ConvertTo-SecureString -AsPlainText -Force
        return New-Object PSCredentialT($VMUsername, $VMPassword)
    }
}

function Get-MgmtCreds {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText",
    "", Justification="This env var is injected by Jenkins.")]
    param()
    $Username = Get-UsernameInWorkgroup -Username $Env:WINCIDEV_USR
    $Password = $Env:WINCIDEV_PSW | ConvertTo-SecureString -asPlainText -Force
    return New-Object PSCredentialT ($Username, $Password)
}

function Get-UsernameInWorkgroup {
    Param ([Parameter(Mandatory = $true)] [string] $Username)
    return "WORKGROUP\{0}" -f $Username
}

function New-RemoteSessions {
    Param ([Parameter(Mandatory = $true)] [Hashtable[]] $VMs)

    $Sessions = [System.Collections.ArrayList] @()
    foreach ($VM in $VMs) {
        $Creds = Get-TestbedCredential -VM $VM
        $Sess = if ($VM['Address']) {
            New-PSSession -ComputerName $VM.Address -Credential $Creds
        } elseif ($VM['VMName']) {
            New-PSSession -VMName $VM.VMName -Credential $Creds
        } else {
            throw "You need to specify 'address' or 'vmName' for a testbed."
        }

        Invoke-Command -Session $Sess -ScriptBlock {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            # Refresh PATH
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "", Justification="We refresh PATH on remote machine, we don't use it here.")]
            $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        }

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
            "", Justification="Issue #804 from PSScriptAnalyzer GitHub")]
        $Sessions += $Sess
    }
    return $Sessions
}

function New-RemoteSessionsToTestbeds {
    Param ([Parameter(Mandatory=$true)] [string] $TestenvConfFile)

    return New-RemoteSessions -VMs (Read-TestbedsConfig -Path $TestenvConfFile)
}
