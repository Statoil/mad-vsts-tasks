function Configure-ApiUsingSwaggerUrl {
    param(
        [string]$WebApp,
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]$Context,
        [string]$ApiName,
        [string]$ApiPath
    )

    $api = Get-AzureRmApiManagementApi -Context $Context -Name $ApiName

    Update-SwaggerAndSaveToFile -WebApp $WebApp -ApiName $ApiName
    if($api){
        Write-Host "`tUpdating existing API at $ApiPath"
        $api = Import-AzureRmApiManagementApi -Context $Context -ApiId $api.ApiId -SpecificationFormat "Swagger" -SpecificationPath "$PSScriptRoot\swagger.json" -Path $ApiPath
    }
    else{
        Write-Host "`tCreating new API at $ApiPath"     
        $apiId = [guid]::NewGuid()   
        $api = Import-AzureRmApiManagementApi -Context $Context -ApiId $apiId -SpecificationFormat "Swagger" -SpecificationPath "$PSScriptRoot\swagger.json" -Path $ApiPath
    }
    return $api
}

function Update-SwaggerAndSaveToFile {
    param(
        [string]$WebApp,
        [string]$ApiName
    )
    Write-Host "`tModifying swagger definition"     
    $hostname = "$WebApp.azurewebsites.net"
	Write-Host "´t $hostname"
    $swagger = Invoke-RestMethod -Method Get -Uri "http://$hostname/swagger/v1/swagger.json"
    $swType = $swagger.GetType().Name
	Write-Host "´t $swType"
	Write-Host "´t $swagger"
    if ($swType -eq "String") {
        #result is recognized as string, not a json object, because of byte order mark
        Write-Host "`tSwagger file format is wrong - convert to json"
        $swagger = ConvertFrom-json -InputObject $swagger.Substring(3)   
    }
    
    $info = $swagger.info
    $info.title = $ApiName
    $swagger | Add-Member -MemberType NoteProperty -Name "host" -value $hostname
    $swagger | Add-Member -MemberType NoteProperty -Name "schemes" -value @("https")
    $swagger | ConvertTo-Json -Depth 100 | Out-File "$PSScriptRoot\swagger.json"
}

function Set-CertificateAuthentication {
    param(
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]$Context,
        [string]$ApiId,
        [string]$Thumbprint
    )
    if(!$Context){
        throw (New-Object System.Exception("No context available"))
    }
    Write-Host "##[command]Set-CertificateAuthentication"    

    $policy = [xml](Get-AzureRmApiManagementPolicy -Context $Context -ApiId $ApiId)
    if(!$policy){
        Write-Host "`tNo policy found - setting default policy"
        $policy = New-Policy
    }

    $certNode = $policy.policies.inbound.ChildNodes | Where-Object {$_.Name -eq "authentication-certificate"}
    if($certNode) {
        Write-Host "`tUpdating thumprint on existing policy"
        $certNode.SetAttribute("thumbprint", $Thumbprint)
    }
    else {
        Write-Host "`tAdding authentication policy"
        $certNode = $policy.CreateElement("authentication-certificate");
        $certNode.SetAttribute("thumbprint", $Thumbprint)
    
        $inbound = $policy.policies.ChildNodes | Where-Object {$_.Name -eq "inbound"}        
        $inbound.AppendChild($certNode)
    }
    Set-AzureRmApiManagementPolicy -Context $Context -ApiId $ApiId -Policy $policy.OuterXml
}

function New-Policy {
    $policy = @"
    <policies>
        <inbound />
        <backend>
                <forward-request />
        </backend>
        <outbound />
</policies>
"@
    return [xml]$policy
}

function Set-ClientCertProperty {
    param(
        [string]$WebAppName, 
        [bool]$Enabled
    )
    Write-Host "##[command]Set-ClientCertProperty -WebAppName $WebAppName -Enabled $Enabled"

    $app = Get-AzureRmWebApp -Name $WebAppName
    $enabledValue = ([string]$Enabled).ToLower() #bool value must be lowercase for api to accept it
    $payload = @"
    {
        "location": "$($app.Location)",
        "properties": {
            "clientCertEnabled": $enabledValue
        }
    }
"@
    $result = Set-AzureRestValue -Uri "$($app.Id)?api-version=2015-04-01" -Payload $payload
}

function Set-CertAppSettings{
    param(
        [string]$WebAppName, 
        $Certificate
    )
    Write-Host "##[command]Set-CertAppSettings"
    $app = Get-AzureRmWebApp -Name $WebAppName
    Set-AppSetting -webappname $WebAppName -ResourceGroupName $app.ResourceGroup -name (Get-VstsInput -Name AppSettingSubject -Require) -value $certificate.Subject
    Set-AppSetting -webappname $WebAppName -ResourceGroupName $app.ResourceGroup -name (Get-VstsInput -Name AppSettingThumbprint -Require) -value $certificate.Thumbprint        
}
