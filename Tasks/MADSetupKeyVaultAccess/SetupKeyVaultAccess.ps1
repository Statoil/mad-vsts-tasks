Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

$certificateLocation = Get-VstsInput -Name CertificateLocation
$certificatePassword = Get-VstsInput -Name CertificatePassword
$vaultName = Get-VstsInput -Name KeyVaultName

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Initialize-Azure

    $global:ErrorActionPreference = 'Continue'
    $global:__vstsNoOverrideVerbose = $true

    Upload-CertificateToKeyVault -certificateLocation $certificateLocation -certificatePassword $certificatePassword -vaultName $vaultName
}
finally{

}

function Upload-CertificateToKeyVault
{
    param(
        [string]$certificateLocation,
        [string]$certificatePassword,
        [string]$vaultName,
        [string]$user
    )
    Write-Host "[MAD] --- Upload certificate to keyvault ---" -ForegroundColor Green
    Write-Host "`tAdding access policies" -ForegroundColor Cyan
    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -ServicePrincipalName abfa0a7c-a6b6-4736-8310-5855508787cd -PermissionsToSecrets All

    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -UserPrincipalName $user -PermissionsToSecrets All 
    
    Write-Host "`tPreparing certificate" -ForegroundColor Cyan
    
    $flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    $collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $collection.Import($certificatePath, $certificatePassword, $flag)
    $pcks12ContentType = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12
    $clearBytes = $collection.Export($pcks12ContentType)
    $fileContentEncoded = [System.Convert]::ToBase64String($clearBytes)
    $secret = ConvertTo-SecureString -String $fileContentEncoded -AsPlainText -Force
    $secretContentType = "application/x-pkcs12"

    Write-Host "`tUploading..." -ForegroundColor Cyan
    $result = Set-AzureKeyVaultSecret -VaultName $vaultName -Name keyVaultCert -SecretValue $secret -ContentType $secretContentType
}

function Add-CertificateToWebApp
{
    param(
        [string]$webApp,
        [string]$vaultName,
        [string]$resourceGroupName
    )
    Write-Host "[MAD] --- Add certificate to web app ---" -ForegroundColor Green    
    Write-Host "`tGenerating payload" -ForegroundColor Cyan
    $app = Get-AzureRmWebApp -Name $webApp
    $vault = Get-AzureRmKeyVault -VaultName $vaultName
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName

    $payload = "{
            'Location': '$($resourceGroup.Location)',
            'Properties': {
                'KeyVaultId': '$($vault.ResourceId)',
                'KeyVaultSecretName': 'keyVaultCert',
                'serverFarmId': '$($app.ServerFarmId)'
                }
            }"

    $resource = $resourceGroup.ResourceId + "/providers/Microsoft.Web/certificates/KeyVaultCert?api-version=2016-03-01"
    Write-Host "`tUploading..." -ForegroundColor Cyan
    $result = ARMClient.exe PUT $resource "$payload"
}