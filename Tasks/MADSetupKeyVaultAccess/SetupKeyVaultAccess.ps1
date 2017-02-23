Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

. "$PSScriptRoot\Util.ps1"

$certificateLocation = Get-VstsInput -Name CertificateLocation
$certificatePassword = Get-VstsInput -Name CertificatePassword
$serviceName = Get-VstsInput -Name "ConnectedServiceNameARM" 
$endpoint = Get-VstsEndpoint -Name $serviceName -Require

$webappName = Get-VstsInput -Name WebApp
$vaultName = Get-VstsInput -Name KeyVaultName
$resourceGroupName = Get-VstsInput -Name resourceGroupName

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Import-Module $PSScriptRoot\ps_modules\MADHelpers
    Initialize-Azure
    Initialize-MAD

    $global:ErrorActionPreference = 'Continue'
    $global:__vstsNoOverrideVerbose = $true
    $user = $endpoint.Auth.Parameters.ServicePrincipalId
    
    Write-Host "##[command]Upload-CertificateToKeyVault"
    Upload-CertificateToKeyVault -certificateLocation "$env:BUILD_SOURCESDIRECTORY\$certificateLocation" -certificatePassword (ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force) -vaultName $vaultName -user $user -tenantId $endpoint.Auth.Parameters.TenantId
    Write-Host "##[command]Add-CertificateToWebApp $webappName in $resourceGroupName"
    Add-CertificateToWebApp $resourceGroupName $webappName $vaultName
}
catch{
    Write-VstsTaskError -Message $_.Exception.Message
}
finally{

}

