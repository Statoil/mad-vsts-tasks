$script:authToken = $null

if ($global:DebugPreference -eq 'Continue') {
    Write-Verbose '$OVERRIDING $global:DebugPreference from ''Continue'' to ''SilentlyContinue''.'
    $global:DebugPreference = 'SilentlyContinue'
}

. $PSScriptRoot/AuthUtil.ps1

function Initialize-MAD {
    [CmdletBinding()]
    param()

    Trace-VstsEnteringInvocation $MyInvocation
    $serviceName = Get-VstsInput -Name "ConnectedServiceNameARM" 
    if (!$serviceName) {
        # Let the task SDK throw an error message if the input isn't defined.
        Get-VstsInput -Name "ConnectedServiceNameARM" -Require
    }

    $endpoint = Get-VstsEndpoint -Name $serviceName -Require

    try{
        Write-Host "##[command]Authenticating..."
        $script:authToken = Get-AuthTokenSpn https://management.azure.com/  $endpoint.Auth.Parameters.TenantId $endpoint.Auth.Parameters.ServicePrincipalId $endpoint.Auth.Parameters.ServicePrincipalKey
    }
    catch{
        Write-VstsTaskError -Message $_.Exception.Message
    }
    finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}
function Get-AzureRestValue {
    [CmdletBinding()]
    param(
        $Uri
    )
    Trace-VstsEnteringInvocation $MyInvocation
    try {
        #Write-Host "##[command]Get-AzureRestValue $Uri"
        
        if(!$script:authToken){
            Write-VstsTaskError -Message "No auth token present"
            return;
        }
        $header = @{
            'Content-Type'='application\json'
            'Authorization'=$script:authToken.CreateAuthorizationHeader()
        }
        $result = Invoke-RestMethod -Uri "https://management.azure.com/$Uri" -Headers $header -Method Get
        return $result
    }
    catch {
        Write-VstsTaskError -Message $_.Exception.Message
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Set-AzureRestValue {
    [CmdletBinding()]
    param(
        $Uri,
        $Payload
    )

    Trace-VstsEnteringInvocation $MyInvocation
    try {
        #Write-Host "##[command]Set-AzureRestValue $Uri"
        
        if(!$script:authToken){
            Write-VstsTaskError -Message "No auth token present"
            return;
        }
        $header = @{
            'Content-Type'='application/json;odata=verbose'
            'Authorization'=$script:authToken.CreateAuthorizationHeader()
        }
        $result = Invoke-RestMethod -Uri "https://management.azure.com/$Uri" -Headers $header -Method Put -Body $Payload
        return $result
    }
    catch {
        Write-VstsTaskError -Message $_.Exception.Message
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}
Export-ModuleMember -Function Initialize-MAD
Export-ModuleMember -Function Get-AzureRestValue
Export-ModuleMember -Function Set-AzureRestValue