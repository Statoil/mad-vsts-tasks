Trace-VstsEnteringInvocation $MyInvocation
$apiManagement = Get-VstsInput -Name ApiManagement -Require
$resourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$productName = Get-VstsInput -Name ApiProduct -Require
$action = Get-VstsInput -Name action -Require

try{
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
    Import-Module $PSScriptRoot\ps_modules\MADHelpers

    Initialize-Azure
    Initialize-MAD -ServiceName (Get-VstsInput -Name "ConnectedServiceName" -Require)

    . "$PSScriptRoot\Util.ps1"

    $global:ErrorActionPreference = 'Stop'
    $global:__vstsNoOverrideVerbose = $true
    
    Write-Host "==== $action ===="
    $ctx = New-AzureRmApiManagementContext -ResourceGroupName $resourceGroupName -ServiceName $apiManagement
    $product = Get-AzureRmApiManagementProduct -Context $ctx -Title $productName

    if($action -eq "Create Or Update API definition") {

        $webapp = Get-VstsInput -Name WebAppName -Require
        $apiName = Get-VstsInput -Name ApiName -Require
        $apiPath = Get-VstsInput -Name ApiPath -Require
        $useCredentials = Get-VstsInput -Name UseProxyCredentials -AsBool
        $certificateThumbprint = Get-VstsInput -Name Certificates

        Write-Host "##[command]Configuring API Management with API $apiName [$apiPath] for $webapp"
        $api = Configure-ApiUsingSwaggerUrl -Context $ctx -WebApp $webapp -ApiName $apiName -ApiPath $apiPath
        
        if(!$product) {
            throw (New-Object System.Exception("Product '$productName' does not exist"))
        }

        Write-Host "##[command]Adding API to product $($product.Title)"    
        
        $result = Add-AzureRmApiManagementApiToProduct -Context $ctx -ProductId $product.ProductId -ApiId $api.ApiId
        $state = [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementProductState]"Published"
        $product = Set-AzureRmApiManagementProduct -Context $ctx -ProductId $product.ProductId -Description $description -ApprovalRequired $approvalRequired -SubscriptionRequired $subscriptionRequired -State $state
        
        if($useCredentials){
            $certificate = Get-AzureRmApiManagementCertificate -Context $ctx | Where-Object {$_.Thumbprint -eq $certificateThumbprint}
            if(!$certificate){
                throw (New-Object System.Exception("Certificate with thumbprint $certificateThumbprint doesn't exist"))
            }
            Set-CertificateAuthentication -Context $ctx -ApiId $api.ApiId -Thumbprint $certificate.Thumbprint
            Set-ClientCertProperty -WebAppName $webapp -Enabled $true
            Set-CertAppSettings -WebAppName $webapp -Certificate $certificate
        }    
        else{
            Set-ClientCertProperty -WebAppName $webapp -Enabled $false
        }
    }
    else {
        $product = Get-AzureRmApiManagementProduct -Context $ctx -Title $productName
        $description = Get-VstsInput -Name Description
        $approvalRequired = Get-VstsInput -Name ApprovalRequired -AsBool
        $subscriptionRequired = Get-VstsInput -Name SubscriptionRequired -AsBool
        $useCredentials = Get-VstsInput -Name UseCertificateCredential -AsBool

        
        if(!$product) {
            Write-Host "##[command]$productName does not exist - creating..."
            $product = New-AzureRmApiManagementProduct -Context $ctx -Title $productName -Description $description -SubscriptionRequired $subscriptionRequired -ApprovalRequired $approvalRequired
        }
        else {
            Write-Host "##[command]Updating $productName"
            if($subscriptionRequired){
                $product = Set-AzureRmApiManagementProduct -Context $ctx -ProductId $product.ProductId -Description $description -ApprovalRequired $approvalRequired -SubscriptionRequired $subscriptionRequired
            }
            else{
                $product = Set-AzureRmApiManagementProduct -Context $ctx -ProductId $product.ProductId -Description $description -SubscriptionRequired $subscriptionRequired                
            }
        }

        if($useCredentials) {
            Get-AzureRmApiManagementCertificate -Context $ctx | Where-Object {$_.Thumbprint -eq $certificate}
        }
    }
    
}
catch {
    Write-VstsTaskError -Message $_.Exception.Message
    throw (New-Object System.Exception("Failed to update API Management", $_.Exception))
}
finally{
    Trace-VstsLeavingInvocation $MyInvocation
}