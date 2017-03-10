Trace-VstsEnteringInvocation $MyInvocation
$webapp = Get-VstsInput -Name WebAppName -Require
$apiManagement = Get-VstsInput -Name ApiManagement -Require
$resourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$apiName = Get-VstsInput -Name ApiName -Require
$apiPath = Get-VstsInput -Name ApiPath -Require
$productName = Get-VstsInput -Name ApiProduct -Require
$useCredentials = Get-VstsInput -Name UseProxyCredentials -AsBool

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Initialize-Azure

    . "$PSScriptRoot\Util.ps1"

    $global:ErrorActionPreference = 'Stop'
    $global:__vstsNoOverrideVerbose = $true
    Write-Host "##[command]Configuring API Management with API $apiName [$apiPath] for $webapp"
    $api = Configure-ApiUsingSwaggerUrl -WebApp $webapp -ApiManagementName $apiManagement -ResourceGroupName $resourceGroupName -ApiName $apiName -ApiPath $apiPath
    $ctx = New-AzureRmApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apiManagement
    $product = Get-AzureRmApiManagementProduct -Context $ctx -Title $productName
    
    if(!$product) {
        Write-Host "##[command]$productName does not exist - creating..."
        $product = New-AzureRmApiManagementProduct -Context $ctx -Title $productName -SubscriptionRequired $false -ApprovalRequired $false -State Published
    }

    Write-Host "##[command]Adding API to product $($product.Title)"    
    $result = Add-AzureRmApiManagementApiToProduct -Context $ctx -ProductId $product.ProductId -ApiId $api.ApiId
}
catch {
    Write-VstsTaskError -Message $_.Exception.Message
    throw (New-Object System.Exception("Failed to update API Management", $_.Exception))
}
finally{
    Trace-VstsLeavingInvocation $MyInvocation
}