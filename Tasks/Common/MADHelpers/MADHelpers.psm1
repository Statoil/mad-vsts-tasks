$script:authToken = $null

if ($global:DebugPreference -eq 'Continue') {
    Write-Verbose '$OVERRIDING $global:DebugPreference from ''Continue'' to ''SilentlyContinue''.'
    $global:DebugPreference = 'SilentlyContinue'
}

. $PSScriptRoot/AuthUtil.ps1
. $PSScriptRoot/New-SWRandomPassword.ps1

function Initialize-MAD {
    [CmdletBinding()]
    param(
        $ServiceName
    )

    Trace-VstsEnteringInvocation $MyInvocation
    if(!$ServiceName){
        $ServiceName = Get-VstsInput -Name "ConnectedServiceNameARM" -Require
    }

    $endpoint = Get-VstsEndpoint -Name $ServiceName -Require

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

function Set-AppSetting {
    [CmdletBinding()]
    param(
        [string]$webappname,
        [string]$ResourceGroupName,
        [string]$name,
        [string]$value
    )
    Trace-VstsEnteringInvocation $MyInvocation
     try {
        Write-Host "##[command]Set-AppSetting $name"
        $webapp = Get-AzureRmWebApp -Name $webappname 
        $appSettings = $webapp.SiteConfig.AppSettings

        $settings = @{}
        foreach($setting in $appSettings){
            $settings[$setting.Name] = $setting.Value
        }
        $settings[$name] = $value

        $app = Set-AzureRmWebApp -Name $webappname -ResourceGroupName $ResourceGroupName -AppSettings $settings
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
Export-ModuleMember -Function Set-AppSetting
Export-ModuleMember -Function New-SWRandomPassword