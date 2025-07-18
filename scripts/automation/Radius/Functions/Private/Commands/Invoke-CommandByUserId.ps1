function Invoke-CommandByUserid {
    [CmdletBinding(DefaultParameterSetName = 'all')]
    param (
        # The userID to of which to invoke the command
        [Parameter(ParameterSetName = 'user')]
        [system.string]
        $userID

    )

    begin {
        # get the command id
        $userObject, $userIndex = Get-UserFromTable -userid $userID

        # get macOS Command
        $macOS_commandId = ($userObject.commandAssociations | Where-Object { $_.commandName -match "MacOSX" }).commandId
        # get Windows Command
        $windows_commandId = ($userObject.commandAssociations | Where-Object { $_.commandName -match "Windows" }).commandId
        # get list of macOS systems
        $macOS_systemIds = Get-SystemsThatNeedCertWork -userData $userObject -osType "macOS"
        # get list of Windows systems
        $windows_systemIds = Get-SystemsThatNeedCertWork -userData $userObject -osType "windows"
    }

    process {
        # explicitly create arrays for windows/ mac system IDs
        $windowsArray = New-Object System.Collections.ArrayList
        foreach ($system in $windows_systemIds) {
            $windowsArray.add($system.systemId) | Out-Null
        }
        $macOSArray = New-Object System.Collections.ArrayList
        foreach ($system in $macOS_systemIds) {
            $macOSArray.add($system.systemId) | Out-Null
        }
        # invoke commands
        If ($macOS_commandId -And $macOSArray) {
            $macInvokedCommands = Start-JcSdkCommand -Id $macOS_commandId -SystemIds $macOSArray
        }

        if ($windows_commandId -And $windowsArray) {
            $windowsInvokedCommands = Start-JcSdkCommand -Id $windows_commandId -SystemIds $windowsArray
        }
    }

    end {
        return $true
    }

}