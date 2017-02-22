function Get-AuthToken
{
    param(
        [Parameter(Mandatory=$true)]
        $ApiEndpointUri,
        [Parameter(Mandatory=$true)]
        $AADTenant
    )

    $adal = "$PSScriptRoot\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = "$PSScriptRoot\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $authorityUri = "https://login.windows.net/$AADTenant"

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authorityUri
    $authResult = $authContext.AcquireToken($ApiEndpointUri, $clientId, $redirectUri, "Auto")

    return $authResult
}

function Get-AuthTokenSpn
{
    param(
        [Parameter(Mandatory=$true)]
        $ApiEndpointUri,
        [Parameter(Mandatory=$true)]
        $AADTenant,
        [Parameter(Mandatory=$true)]
        $ClientId,
        [Parameter(Mandatory=$true)]
        $Secret
    )

    $adal = "$PSScriptRoot\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = "$PSScriptRoot\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $authorityUri = "https://login.windows.net/$AADTenant"

    $credential = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential" -ArgumentList $ClientId, $Secret
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authorityUri
    $authResult = $authContext.AcquireToken($ApiEndpointUri, $credential)

    return $authResult
}