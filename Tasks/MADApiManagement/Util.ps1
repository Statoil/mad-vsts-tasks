function Configure-ApiUsingSwaggerUrl {
    param(
        [string]$WebApp,
        [string]$ApiManagementName,
        [string]$ResourceGroupName,
        [string]$ApiName,
        [string]$ApiPath
    )

    $ctx = New-AzureRmApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApiManagementName
    $api = Get-AzureRmApiManagementApi -Context $ctx -Name $ApiName

    Update-SwaggerAndSaveToFile -WebApp $WebApp -ApiName $ApiName
    if($api){
        Write-Host "`tUpdating existing API at $ApiPath"
        Import-AzureRmApiManagementApi -Context $ctx -ApiId $api.ApiId -SpecificationFormat "Swagger" -SpecificationPath "$PSScriptRoot\swagger.json" -Path $ApiPath
    }
    else{
        Write-Host "`tCreating new API at $ApiPath"     
        $apiId = [guid]::NewGuid()   
        $api = Import-AzureRmApiManagementApi -Context $ctx -ApiId $apiId -SpecificationFormat "Swagger" -SpecificationPath "$PSScriptRoot\swagger.json" -Path $ApiPath
    }
}

function Update-SwaggerAndSaveToFile {
    param(
        [string]$WebApp,
        [string]$ApiName
    )
    Write-Host "`tModifying swagger definition"     
    $hostname = "$WebApp.azurewebsites.net"
    $swagger = Invoke-RestMethod -Method Get -Uri "https://$hostname/swagger/v1/swagger.json"
    $info = $swagger.info
    $info.title = $ApiName
    $swagger | Add-Member -MemberType NoteProperty -Name "host" -value $hostname
    $swagger | Add-Member -MemberType NoteProperty -Name "schemes" -value @("https")
    $swagger | ConvertTo-Json -Depth 100 | Out-File "$PSScriptRoot\swagger.json"
}