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

    $global:ErrorActionPreference = 'Continue'
    $global:__vstsNoOverrideVerbose = $true
    
    if ($useCertificate) {
        $x509 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $x509.Import($certificatePath)
        $credentials = [System.Convert]::ToBase64String($x509.GetRawCertData())
    }
    
    $adApp = New-AzureRmADApplication -DisplayName $applicationName -HomePage $signInUrl -IdentifierUris $identifierUri

    Write-Host ("##vso[applicationid]$app.ApplicationId")
}
finally{
    
}