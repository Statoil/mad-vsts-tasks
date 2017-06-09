Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

$applicationName = Get-VstsInput -Name ApplicationName -Require
$signInUrl = Get-VstsInput -Name SignInUrl -Require
$identifierUri = Get-VstsInput -Name IdentifierUri -Require
$useCertificate = Get-VstsInput -Name AddCertificateCredential
$createKey = Get-VstsInput -Name AddKey -AsBool
$certificateLocation = Get-VstsInput -Name CertificateLocation

try {
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Import-Module $PSScriptRoot\ps_modules\MADHelpers

    Initialize-Azure

    . "$PSScriptRoot\Util.ps1"

    $global:ErrorActionPreference = 'Stop'
    $global:__vstsNoOverrideVerbose = $true
    
    if ($useCertificate -eq $true) {
        $certificateLocation = Get-VstsInput -Name CertificateLocation
        $certificatePassword = Get-VstsInput -Name CertificatePassword
        $pfx = Get-Certificate -certificateLocation $certificateLocation -certificatePassword (ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force)
    } 
    
    $apps = Get-AzureRmADApplication -DisplayNameStartWith $applicationName
    if ($apps -and $apps.Length -gt 1) {
        Write-Host "`t$($apps.Length) application(s) found starting with '$applicationName'" -ForegroundColor Red
        exit
    }
    if ($apps.Length -eq 1) {
        Write-Host "`t'$applicationName' already exists"
        $applicationId = $apps[0].ApplicationId
        if ($useCertificate -eq $true) { 
            Write-Host "`tUpdating credentials for application"
            Update-CertificateCredentials -applicationId $applicationId -certificate $pfx
            $sp = Create-ServicePrincipal $apps[0]
        }
        if ($createKey) {
            Write-Host "`tCreating key..."            
            $key = New-SWRandomPassword -PasswordLength 16
            New-AzureRmADAppCredential -ApplicationId $applicationId -Password $key
            Write-Host "##vso[task.setvariable variable=APPLICATIONKEYSECRET;issecret=true;]$key"                        
        }
        Write-Host "##vso[task.setvariable variable=APPLICATIONID;]$applicationId"            
        return
    }

    if ($useCertificate -eq $true) {
        $credentials = [System.Convert]::ToBase64String($pfx.GetRawCertData())
        $adApp = New-AzureRmADApplication -DisplayName $applicationName -HomePage $signInUrl -IdentifierUris $identifierUri -CertValue $credentials -StartDate $pfx.NotBefore -EndDate $pfx.NotAfter
        $sp = Create-ServicePrincipal $adApp
    }
    else {
        $adApp = New-AzureRmADApplication -DisplayName $applicationName -HomePage $signInUrl -IdentifierUris $identifierUri
    }

    if ($createKey) {
        Write-Host "`tCreating key..."
        $key = New-SWRandomPassword -PasswordLength 16
        New-AzureRmADAppCredential -ApplicationId $adApp.ApplicationId -Password $key
        Write-Host "##vso[task.setvariable variable=APPLICATIONKEYSECRET;issecret=true;]$key"                        
    }

    Write-Host "##vso[task.setvariable variable=APPLICATIONID;]$($adApp.ApplicationId)"
}
catch {
    Write-VstsTaskError -Message $_.Exception.Message
    throw (New-Object System.Exception("Failed to create Azure AD Application", $_.Exception))
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
