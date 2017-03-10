Trace-VstsEnteringInvocation $MyInvocation
$webapp = Get-VstsInput -Name WebAppName -Require
$apiManagement = Get-VstsInput -Name ApiManagement -Require
$resourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$apiName = Get-VstsInput -Name ApiName -Require
$apiPath = Get-VstsInput -Name ApiPath -Require

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Initialize-Azure

    . "$PSScriptRoot\Util.ps1"

    $global:ErrorActionPreference = 'Stop'
    $global:__vstsNoOverrideVerbose = $true
    Write-Host "##[command]Configuring API Management with API $apiName [$apiPath] for $webapp"
    Configure-ApiUsingSwaggerUrl -WebApp $webapp -ApiManagementName $apiManagement -ResourceGroupName $resourceGroupName -ApiName $apiName -ApiPath $apiPath
}
catch {
    Write-VstsTaskError -Message $_.Exception.Message
    throw (New-Object System.Exception("Failed to update API Management", $_.Exception))
}
finally{
    Trace-VstsLeavingInvocation $MyInvocation
}