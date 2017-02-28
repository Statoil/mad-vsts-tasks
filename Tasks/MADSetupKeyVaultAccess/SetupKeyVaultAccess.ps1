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
$adAppName = Get-VstsInput -Name AzureADApplication

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Import-Module $PSScriptRoot\ps_modules\MADHelpers
    Initialize-Azure
    Initialize-MAD

    $global:ErrorActionPreference = 'Continue'
    $global:__vstsNoOverrideVerbose = $true
    $user = $endpoint.Auth.Parameters.ServicePrincipalId

    Write-Host "##[command]Adding Azure management to access policy"
    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -ServicePrincipalName abfa0a7c-a6b6-4736-8310-5855508787cd -PermissionsToSecrets All

    Write-Host "##[command]Adding $tenantId $user to access policy"
    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -ServicePrincipalName $user -PermissionsToSecrets All

    $adApp = Get-AzureRmADApplication -DisplayNameStartWith $adAppName
    Write-Host "##[command]Add-KeyVaultAccessPolicy $($adApp[0].DisplayName)"
    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -ServicePrincipalName $adApp[0].ApplicationId -PermissionsToSecrets All

    $pfx = Get-Certificate -certificateLocation $certificateLocation -certificatePassword (ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force)
    Write-Host "##[command]Upload-CertificateToKeyVault"
    Upload-CertificateToKeyVault -certificate $pfx -vaultName $vaultName -user $user -tenantId $endpoint.Auth.Parameters.TenantId

    Write-Host "##[command]Add-CertificateToWebApp $webappName in $resourceGroupName"
    Add-CertificateToWebApp $resourceGroupName $webappName $vaultName
    Set-AppSetting $webappName $resourceGroupName "Keyvault:Name" "$vaultName"
    Set-AppSetting $webappName $resourceGroupName "Keyvault:Thumbprint" "$($pfx.Thumbprint)"
    Set-AppSetting $webappName $resourceGroupName "WEBSITE_LOAD_CERTIFICATES" "$($pfx.Thumbprint)"
}
catch{
    Write-VstsTaskError -Message $_.Exception.Message
    throw (New-Object System.Exception("Failed to configure keyvault access", $_.Exception))
}
finally{
    Trace-VstsLeavingInvocation $MyInvocation
}

