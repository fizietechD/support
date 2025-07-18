# import helper functions:
. "$PSScriptRoot/HelperFunctions.ps1"
# beforeAll, remove PesterRadiusGroup + users
Write-Warning "Removing Pester Radius User Groups with name: PesterRadiusGroup*"
$pesterRadiusGroups = Get-JcSdkUserGroup -filter "name:search:PesterRadiusGroup"
foreach ($pesterRadiusGroup in $pesterRadiusGroups) {
    Remove-JcSdkUserGroup -Id $pesterRadiusGroup.Id | Out-Null
}

Write-Warning "Removing Pester Radius Users with emailDomain: *pesterradtest.com"
$pesterRadiusUsers = Get-JCUser -email "*pesterradtest.com"
foreach ($user in $pesterRadiusUsers) {
    Remove-JcSdkUser -Id $user.id | Out-Null
}
# remove existing users created in test:
Write-Warning "Removing Pester Radius Users with emailDomain: *pesterRadius*"
$usersToRemove = Get-JCuser -email "*pesterRadius*" | Remove-JCUser -force

# remove existing radius commands in test:
Write-Warning "Removing Pester Radius Commands"
$commandsToRemove = Get-JCCommand -Name "RadiusCert-Install:*"
foreach ($commandToRemove in $commandsToRemove) {
    Remove-JCCommand -CommandID $commandToRemove._id -force | out-null
}

# Create users
Write-Warning "Creating New Pester Radius Users"
# user bound to mac
$macUser = New-RandomUser -Domain "PesterRadTest" | New-JCUser
$macOSSystem = Get-JCSystem -os "Mac OS X" | Get-Random -Count 1
Set-JcSdkSystemAssociation -SystemId $macOSSystem.id -id $macUser.id -Type 'user' -Op "add"
Write-Host "MacOS System Name: $($macOSSystem.displayName) | Associated User Name: $($macUser.username)"
# user bound to windows

$windowsUser = New-RandomUser -Domain "PesterRadTest" | New-JCUser
$windowsSystem = Get-JCSystem -os "Windows" | Get-Random -Count 1
Set-JcSdkSystemAssociation -SystemId $macOSSystem.id -id $windowsUser.id -Type 'user' -Op "add"
Write-Host "Windows System Name: $($windowsSystem.displayName) |  Associated User Name: $($windowsUser.username)"
# user bound to both macOS and windows
$bothUser = New-RandomUser -Domain "PesterRadTest" | New-JCUser
Set-JcSdkSystemAssociation -SystemId $macOSSystem.id -id $bothUser.id -Type 'user' -Op "add"
Set-JcSdkSystemAssociation -SystemId $windowsSystem.id -id $bothUser.id -Type 'user' -Op "add"
Write-Host "Windows System Name: $($windowsSystem.displayName) | Mac System Name: $($macOSSystem.displayName) |  Associated User Name: $($bothUser.username)"

# create user group + Add membership
Write-Warning "Creating New Pester Radius Group"
$randomNum = (Get-Random -Minimum 900 -Maximum 999)
$radiusUserGroup = New-JCUserGroup -GroupName "PesterRadiusGroup-$randomNum"
Set-JcSdkUserGroupMember -GroupId $radiusUserGroup.Id -Id $macUser.id -Op "add"
Set-JcSdkUserGroupMember -GroupId $radiusUserGroup.Id -Id $windowsUser.id -Op "add"
Set-JcSdkUserGroupMember -GroupId $radiusUserGroup.Id -Id $bothUser.id -Op "add"

# set a rootKeyPassword
$env:certKeyPassword = "testCertificate123!@#"

# update config:
Write-Warning "Updating Config File"

# Create a new Radius directory
$radiusDirectory = Join-Path -Path $HOME -ChildPath "RADIUS"
if (-Not (Test-Path -Path $radiusDirectory)) {
    New-Item -ItemType Directory -Path $radiusDirectory | Out-Null
}

# Update the userGroupID:
$settings = @{
    certType          = "UsernameCn"
    certSecretPass    = "secret1234!"
    radiusDirectory   = "$(Resolve-Path $HOME/RADIUS)"
    networkSSID       = "TP-Link_SSID"
    userGroup         = $radiusUserGroup.id
    openSSLBinary     = 'openssl'
    certSubjectHeader = @{
        CountryCode      = "US"
        StateCode        = "CO"
        Locality         = "Boulder"
        Organization     = "JumpCloud"
        OrganizationUnit = "Customer_Tools"
        CommonName       = "JumpCloud.com"
    }
}

Set-JCRConfig @settings
# update the openSSL path:
if ($IsMacOS) {
    $brewList = brew list openssl@3
    if (-Not ($brewList)) {
        Write-Warning "OpenSSL v3 is not installed on this system. Attempting to install..."
        try {
            brew install openssl@3
        } catch {
            Write-Host could not install openssl
        }
    }

    $brewListBinary = $brewList | Where-Object { $_ -match "/bin/openssl" }
    $regMatch = $brewListBinary | Select-String -pattern "\/([0-9].[0-9].[0-9])\/"
    $opensslVersion = $regMatch.matches.groups[1].value

    Write-Warning "OpenSSL Version: $opensslVersion is installed via homebrew on this system; updating config:"
}

$env:certKeyPassword = "TestCertificate123!@#"
Import-Module "$psscriptRoot/../JumpCloud.Radius.psd1" -Force