function Update-CertificateCredentials {
    param(
        [string]$applicationId,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$certificate
    )
    try{
        Write-Host "##[command]Updating certificate for $applicationId"    
        $credentials = [System.Convert]::ToBase64String($certificate.GetRawCertData())
        Write-Host "`tRemoving current credentials"
        Remove-AzureRmADAppCredential -ApplicationId $applicationId -All -Force 
        Write-Host "`tAdding new credentials"
        New-AzureRmADAppCredential -ApplicationId $applicationId -CertValue $credentials -EndDate $certificate.NotAfter -StartDate $certificate.NotBefore
    }
    catch{
        $Error = $_.Exception.Message
        Write-Host "Error occured: $Error" -ForegroundColor Red
    }
}
function Create-ServicePrincipal {
    param(
        [object]$application
    )
    Write-Host "##[command]Create-ServicePrincipal"    
    
    if($application -eq $null) {
        Write-Host "No application provided" 
        exit
    }
    $sp = Get-AzureRmADServicePrincipal -SearchString $application.DisplayName
    if($sp -eq $null) {
        Write-Host "`tCreating service principal for '$($application.DisplayName)'" 
        $sp = New-AzureRmADServicePrincipal -ApplicationId $application.ApplicationId
    }
    else {
        Write-Host "`tService principal '$($sp.DisplayName)' already exists" 
    }
    return $sp
}
function Get-Certificate {
    param(
        [string]$certificateLocation,
        [securestring]$certificatePassword
    )

    Write-Host "##[command]Importing $certificateLocation"    
    $flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $pfx.Import($certificateLocation, $certificatePassword, $flag)
    
    return $pfx
}