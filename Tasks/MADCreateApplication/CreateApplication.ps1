Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

$applicationName = Get-VstsInput -Name ApplicationName -Require
$signInUrl = Get-VstsInput -Name SignInUrl -Require
$identifierUri = Get-VstsInput -Name IdentifierUri -Require
$useCertificate = Get-VstsInput -Name AddCertificateCredential
$certificateLocation = Get-VstsInput -Name CertificateLocation

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Initialize-Azure

    . "$PSScriptRoot\Util.ps1"

    $global:ErrorActionPreference = 'Stop'
    $global:__vstsNoOverrideVerbose = $true
    
    if ($useCertificate) {
        $certificateLocation = Get-VstsInput -Name CertificateLocation
        $certificatePassword = Get-VstsInput -Name CertificatePassword
        $pfx = Get-Certificate -certificateLocation $certificateLocation -certificatePassword (ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force)
    } 
    
    $apps = Get-AzureRmADApplication -DisplayNameStartWith $applicationName
    if($apps -and $apps.Length -gt 1) {
        Write-Host "`t$($apps.Length) application(s) found starting with '$applicationName'" -ForegroundColor Red
        exit
    }
    if($apps.Length -eq 1) {
        Write-Host "`t'$applicationName' already exists"
        if($useCertificate) { 
            Write-Host "`tUpdating credentials for application"
            Update-CertificateCredentials -applicationId $apps[0].ApplicationId -certificate $pfx
            $sp =  Create-ServicePrincipal $apps[0]
        }
        return
    }

    if($useCertificate) {
        $credentials = [System.Convert]::ToBase64String($pfx.GetRawCertData())
        $adApp = New-AzureRmADApplication -DisplayName $applicationName -HomePage $signInUrl -IdentifierUris $identifierUri -CertValue $credentials -StartDate $pfx.NotBefore -EndDate $pfx.NotAfter
        $sp =  Create-ServicePrincipal $adApp
    }
    else {
        $adApp = New-AzureRmADApplication -DisplayName $applicationName -HomePage $signInUrl -IdentifierUris $identifierUri
    }
    
    Write-Host ("##vso[setvariable variable=APPLICATIONID]$($app.ApplicationId)")
}
catch {
    Write-VstsTaskError -Message $_.Exception.Message
    throw (New-Object System.Exception("Failed to create Azure AD Application", $_.Exception))
}
finally{
    Trace-VstsLeavingInvocation $MyInvocation
}