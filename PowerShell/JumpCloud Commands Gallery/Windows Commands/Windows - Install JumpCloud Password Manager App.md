#### Name


Windows - Install and Update JumpCloud Password Manager App | v2.0.0 JCCG


#### commandType

windows

#### Command

```

# Set $LaunchPasswordManager to $false  ON LINE 70 if you do not wish to launch the password manger after installation

# Set $updateToLatest to $true if you want to update to the latest version of JumpCloud Password Manager
# Set $updateToLatest to $false if you want to re-install the JumpCloud Password Manager no matter your current version.
# ********** DISCLAIMER: Setting $updateToLatest to $false will NOT affect any user data **********
$updateToLatest = $true
# Get the current logged on User
$loggedUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
$loggedUser = $loggedUser -replace '.*\\'

# Construct the Registry path using the user's SID
$userSID = (New-Object System.Security.Principal.NTAccount($loggedUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSID"

# Get the ProfileImagePath value from the Registry
$loggedOnUserProfileImagePath = Get-ItemPropertyValue -Path $registryPath -Name 'ProfileImagePath'
Write-Output "Logged On User Profile Path: $loggedOnUserProfileImagePath"


$appDataPath = "$loggedOnUserProfileImagePath\AppData\Local\jcpwm"

$installerURL = 'https://cdn.pwm.jumpcloud.com/DA/release/JumpCloud-Password-Manager-latest.exe'
$yamlFileURL =  'https://cdn.pwm.jumpcloud.com/DA/release/latest.yml'

# If user already has the app installed and admin wants to update to latest
if ((Test-Path "$appDataPath") -and ($updateToLatest -eq $true)) {
    $folderPrefix = "app-"
    $versionFolders = Get-ChildItem -Path $appDataPath -Directory |
                  Where-Object { $_.Name -like "$($folderPrefix)*" } |
                  Sort-Object Name -Descending

    if ($versionFolders.Count -gt 0) {
        # Get the name of the top (latest) matching folder (app-x.x.x)
        $latestFolderName = $versionFolders[0].Name
        # Extract the version string by splitting the folder name
        # We split by the prefix and take the last part (which is the version)
        [System.Version]$currentInstalledAppVersion = ($latestFolderName.Split($folderPrefix, [System.StringSplitOptions]::RemoveEmptyEntries))[-1].Trim()
    } else {
        Write-Output "App Folder is missing, revert to full download"
        $updateToLatest = $false
    }
}

if (Test-Path "$loggedOnUserProfileImagePath\AppData\Local\Temp" ) {

    $installerTempLocation = "$loggedOnUserProfileImagePath\AppData\Local\Temp\JumpCloud-Password-Manager-latest.exe"
    $yamlFileTempLocation = "$loggedOnUserProfileImagePath\AppData\Local\Temp\jcpwm-latest.yml"
    Write-Output "Installer Location: $installerTempLocation"
}
else {
    Write-Output "Unable to determine user profile folder"
    Exit 1
}

if ($updateToLatest -eq $true) {
    # Remove existing YAML file to ensure fresh version check
    if (Test-Path -Path $yamlFileTempLocation) {
        Remove-Item -Path $yamlFileTempLocation -Force
    }

    if (-not(Test-Path -Path $yamlFileTempLocation -PathType Leaf)) {
        try {
            Write-Output 'Downloading Password Manager installer now.'
            try {
                Invoke-WebRequest -Uri $yamlFileURL -OutFile $yamlFileTempLocation
            } catch {
                Write-Error "Unable to download Password Manager latest yml file to $yamlFileTempLocation."
                exit 1
            }
            Write-Output 'Finished downloading Password Manager installer.'
        } catch {
            throw $_.Exception.Message
        }
    }

    $versionLine = Get-Content -Path $yamlFileTempLocation | Select-String -Pattern 'version[^\w:]*:\s*(.*)$'
    Write-Output "Checking for version in YAML file: $yamlFileTempLocation"
    Write-Output "Version Line: $versionLine"
    if ($versionLine) {
    # Extract the version number from the matched line
    # The 'Groups[1]' captures the content after 'version: '
    [System.Version]$latestVersion = $versionLine.Matches[0].Groups[1].Value.Trim()
    Write-Output "Latest version: $latestVersion"
    # If the admin has previously installed the dogfood/beta version of the app for the users
    # it might be greater than the version found under the $installerURL.
    if ($currentInstalledAppVersion -ge $latestVersion) {
            Write-Output "App is already up to date, exiting."
            Exit 0
        }
    } else {
        Write-Warning "Could not find 'version' in the YAML file, falling back to full download."
    }
}

Write-Output "Ensuring a fresh installer download..."
# Remove existing installer file to ensure fresh download
if (Test-Path -Path $installerTempLocation) {
    Remove-Item -Path $installerTempLocation -Force
}

Write-Output 'Testing if Password Manager installer is downloaded'

if (-not(Test-Path -Path $installerTempLocation -PathType Leaf)) {
    try {
        Write-Output 'Downloading Password Manager installer now.'
        try {
            Invoke-WebRequest -Uri $installerURL -OutFile $installerTempLocation
        } catch {
            Write-Error "Unable to download Password Manager installer to $InstallerTempLocation."
            exit 1
        }
        Write-Output 'Finished downloading Password Manager installer.'
    } catch {
        throw $_.Exception.Message
    }
}

Write-Output "Checking if JumpCloud Password Manager is running."
$process = Get-Process | Where-Object { $_.ProcessName -like "*JumpCloud Password Manager*" }
if ($process) {
    Write-Output "JumpCloud Password Manager is running. Terminating process before installation."
    Stop-Process -Name $process.ProcessName -Force
    # Clean the process
    Start-Sleep -Seconds 5
}

Write-Output 'Installing Password Manager now, this may take a few minutes.'

$Command = {
    # Get the current user's SID (Security Identifier)
    $loggedUser = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
    $loggedUser = $loggedUser -replace '.*\\'

    # Construct the Registry path using the user's SID
    $userSID = (New-Object System.Security.Principal.NTAccount($loggedUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSID"
    $loggedOnUserProfileImagePath = Get-ItemPropertyValue -Path $registryPath -Name 'ProfileImagePath'
    $LaunchPasswordManager = $true
    $installerTempLocation = "$loggedOnUserProfileImagePath\AppData\Local\Temp\JumpCloud-Password-Manager-latest.exe"
    if ($LaunchPasswordManager -eq $false) {
        $env:QUIT_PWM_AFTER_INITIAL_INSTALL="true"
    }
    . $installerTempLocation

    if ($LaunchPasswordManager -eq $false) {
        # If the user does not want to launch the password manager after installation
        # no shortcut will be created so we'll have to do it manually.
        # Wait for the installer to finish before proceeding
        Write-Output "Waiting for JumpCloud Password Manager installer to finish."
        Wait-Process -Name "JumpCloud-Password-Manager-latest"
        Write-Output "Creating shortcut to JumpCloud Password Manager on the Desktop"

        $appTargetPath = "$appDataPath\JumpCloud Password Manager.exe"

        $shell = New-Object -comObject WScript.Shell
        $desktopShortcut = $shell.CreateShortcut("$loggedOnUserProfileImagePath\Desktop\JumpCloud Password Manager.lnk")
        $desktopShortcut.TargetPath = "$appTargetPath"
        $desktopShortcut.WorkingDirectory = "$appDataPath"
        $desktopShortcut.Save()
        Write-Output "Shortcut created on the Desktop."
        Write-Output "Now Creating Start Menu Shortcut."
        $startMenuDirectory = "$loggedOnUserProfileImagePath\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\JumpCloud Inc"
        if (-not(Test-Path -Path $startMenuDirectory)) {
            New-Item -Path $startMenuDirectory -ItemType Directory
        }
        $startMenuShortcut = $shell.CreateShortcut("$startMenuDirectory\JumpCloud Password Manager.lnk")
        $startMenuShortcut.TargetPath = "$appTargetPath"
        $startMenuShortcut.WorkingDirectory = "$appDataPath"
        $startMenuShortcut.Save()
        Write-Output "Start Menu Shortcut created."
     }
}

$Source = @'
using System;
using System.Runtime.InteropServices;

namespace murrayju.ProcessExtensions
{
   public static class ProcessExtensions
   {
       #region Win32 Constants

       private const int CREATE_UNICODE_ENVIRONMENT = 0x00000400;
       private const int CREATE_NO_WINDOW = 0x08000000;

       private const int CREATE_NEW_CONSOLE = 0x00000010;

       private const uint INVALID_SESSION_ID = 0xFFFFFFFF;
       private static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;

       #endregion

       #region DllImports

       [DllImport("advapi32.dll", EntryPoint = "CreateProcessAsUser", SetLastError = true, CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
       private static extern bool CreateProcessAsUser(
           IntPtr hToken,
           String lpApplicationName,
           String lpCommandLine,
           IntPtr lpProcessAttributes,
           IntPtr lpThreadAttributes,
           bool bInheritHandle,
           uint dwCreationFlags,
           IntPtr lpEnvironment,
           String lpCurrentDirectory,
           ref STARTUPINFO lpStartupInfo,
           out PROCESS_INFORMATION lpProcessInformation);

       [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
       private static extern bool DuplicateTokenEx(
           IntPtr ExistingTokenHandle,
           uint dwDesiredAccess,
           IntPtr lpThreadAttributes,
           int TokenType,
           int ImpersonationLevel,
           ref IntPtr DuplicateTokenHandle);

       [DllImport("userenv.dll", SetLastError = true)]
       private static extern bool CreateEnvironmentBlock(ref IntPtr lpEnvironment, IntPtr hToken, bool bInherit);

       [DllImport("userenv.dll", SetLastError = true)]
       [return: MarshalAs(UnmanagedType.Bool)]
       private static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);

       [DllImport("kernel32.dll", SetLastError = true)]
       private static extern bool CloseHandle(IntPtr hSnapshot);

       [DllImport("kernel32.dll")]
       private static extern uint WTSGetActiveConsoleSessionId();

       [DllImport("Wtsapi32.dll")]
       private static extern uint WTSQueryUserToken(uint SessionId, ref IntPtr phToken);

       [DllImport("wtsapi32.dll", SetLastError = true)]
       private static extern int WTSEnumerateSessions(
           IntPtr hServer,
           int Reserved,
           int Version,
           ref IntPtr ppSessionInfo,
           ref int pCount);

       #endregion

       #region Win32 Structs

       private enum SW
       {
           SW_HIDE = 0,
           SW_SHOWNORMAL = 1,
           SW_NORMAL = 1,
           SW_SHOWMINIMIZED = 2,
           SW_SHOWMAXIMIZED = 3,
           SW_MAXIMIZE = 3,
           SW_SHOWNOACTIVATE = 4,
           SW_SHOW = 5,
           SW_MINIMIZE = 6,
           SW_SHOWMINNOACTIVE = 7,
           SW_SHOWNA = 8,
           SW_RESTORE = 9,
           SW_SHOWDEFAULT = 10,
           SW_MAX = 10
       }

       private enum WTS_CONNECTSTATE_CLASS
       {
           WTSActive,
           WTSConnected,
           WTSConnectQuery,
           WTSShadow,
           WTSDisconnected,
           WTSIdle,
           WTSListen,
           WTSReset,
           WTSDown,
           WTSInit
       }

       [StructLayout(LayoutKind.Sequential)]
       private struct PROCESS_INFORMATION
       {
           public IntPtr hProcess;
           public IntPtr hThread;
           public uint dwProcessId;
           public uint dwThreadId;
       }

       private enum SECURITY_IMPERSONATION_LEVEL
       {
           SecurityAnonymous = 0,
           SecurityIdentification = 1,
           SecurityImpersonation = 2,
           SecurityDelegation = 3,
       }

       [StructLayout(LayoutKind.Sequential)]
       private struct STARTUPINFO
       {
           public int cb;
           public String lpReserved;
           public String lpDesktop;
           public String lpTitle;
           public uint dwX;
           public uint dwY;
           public uint dwXSize;
           public uint dwYSize;
           public uint dwXCountChars;
           public uint dwYCountChars;
           public uint dwFillAttribute;
           public uint dwFlags;
           public short wShowWindow;
           public short cbReserved2;
           public IntPtr lpReserved2;
           public IntPtr hStdInput;
           public IntPtr hStdOutput;
           public IntPtr hStdError;
       }

       private enum TOKEN_TYPE
       {
           TokenPrimary = 1,
           TokenImpersonation = 2
       }

       [StructLayout(LayoutKind.Sequential)]
       private struct WTS_SESSION_INFO
       {
           public readonly UInt32 SessionID;

           [MarshalAs(UnmanagedType.LPStr)]
           public readonly String pWinStationName;

           public readonly WTS_CONNECTSTATE_CLASS State;
       }

       #endregion

       // Gets the user token from the currently active session
       private static bool GetSessionUserToken(ref IntPtr phUserToken)
       {
           var bResult = false;
           var hImpersonationToken = IntPtr.Zero;
           var activeSessionId = INVALID_SESSION_ID;
           var pSessionInfo = IntPtr.Zero;
           var sessionCount = 0;

           // Get a handle to the user access token for the current active session.
           if (WTSEnumerateSessions(WTS_CURRENT_SERVER_HANDLE, 0, 1, ref pSessionInfo, ref sessionCount) != 0)
           {
               var arrayElementSize = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
               var current = pSessionInfo;

               for (var i = 0; i < sessionCount; i++)
               {
                   var si = (WTS_SESSION_INFO)Marshal.PtrToStructure((IntPtr)current, typeof(WTS_SESSION_INFO));
                   current += arrayElementSize;

                   if (si.State == WTS_CONNECTSTATE_CLASS.WTSActive)
                   {
                       activeSessionId = si.SessionID;
                   }
               }
           }

           // If enumerating did not work, fall back to the old method
           if (activeSessionId == INVALID_SESSION_ID)
           {
               activeSessionId = WTSGetActiveConsoleSessionId();
           }

           if (WTSQueryUserToken(activeSessionId, ref hImpersonationToken) != 0)
           {
               // Convert the impersonation token to a primary token
               bResult = DuplicateTokenEx(hImpersonationToken, 0, IntPtr.Zero,
                   (int)SECURITY_IMPERSONATION_LEVEL.SecurityImpersonation, (int)TOKEN_TYPE.TokenPrimary,
                   ref phUserToken);

               CloseHandle(hImpersonationToken);
           }

           return bResult;
       }

       public static bool StartProcessAsCurrentUser(string appPath, string cmdLine = null, string workDir = null, bool visible = true)
       {
           var hUserToken = IntPtr.Zero;
           var startInfo = new STARTUPINFO();
           var procInfo = new PROCESS_INFORMATION();
           var pEnv = IntPtr.Zero;
           int iResultOfCreateProcessAsUser;

           startInfo.cb = Marshal.SizeOf(typeof(STARTUPINFO));

           try
           {
               if (!GetSessionUserToken(ref hUserToken))
               {
                   throw new Exception("StartProcessAsCurrentUser: GetSessionUserToken failed.");
               }

               uint dwCreationFlags = CREATE_UNICODE_ENVIRONMENT | (uint)(visible ? CREATE_NEW_CONSOLE : CREATE_NO_WINDOW);
               startInfo.wShowWindow = (short)(visible ? SW.SW_SHOW : SW.SW_HIDE);
               startInfo.lpDesktop = "winsta0\\default";

               if (!CreateEnvironmentBlock(ref pEnv, hUserToken, false))
               {
                   throw new Exception("StartProcessAsCurrentUser: CreateEnvironmentBlock failed.");
               }

               if (!CreateProcessAsUser(hUserToken,
                   appPath, // Application Name
                   cmdLine, // Command Line
                   IntPtr.Zero,
                   IntPtr.Zero,
                   false,
                   dwCreationFlags,
                   pEnv,
                   workDir, // Working directory
                   ref startInfo,
                   out procInfo))
               {
                   throw new Exception("StartProcessAsCurrentUser: CreateProcessAsUser failed.\n");
               }

               iResultOfCreateProcessAsUser = Marshal.GetLastWin32Error();
           }
           finally
           {
               CloseHandle(hUserToken);
               if (pEnv != IntPtr.Zero)
               {
                   DestroyEnvironmentBlock(pEnv);
               }
               CloseHandle(procInfo.hThread);
               CloseHandle(procInfo.hProcess);
           }
           return true;
       }
   }
}


'@

Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $Source -Language CSharp
$ApplicationPath = 'C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe'

$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encodedCommand = [Convert]::ToBase64String($bytes)
$Arguments = '-NoLogo -NonInteractive -ExecutionPolicy ByPass -WindowStyle Hidden -encodedCommand ' + $encodedCommand
[murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser($ApplicationPath, $Arguments)
```

#### Description

This command will download and install the JumpCloud Password Manager app to the device if it isn't already installed. On slower networks, timeouts with exit code 127 can occur. Manually setting the default timeout limit to 600 seconds may be advisable.

#### _Import This Command_

To import this command into your JumpCloud tenant run the below command using the [JumpCloud PowerShell Module](https://github.com/TheJumpCloud/support/wiki/Installing-the-JumpCloud-PowerShell-Module)

```
$command = Import-JCCommand -URL "https://github.com/TheJumpCloud/support/blob/master/PowerShell/JumpCloud%20Commands%20Gallery/Windows%20Commands/Windows%20-%20Install%20JumpCloud%20Password%20Manager%20App.md"
Set-JCCommand -CommandID $command.id -timeout 600
```
