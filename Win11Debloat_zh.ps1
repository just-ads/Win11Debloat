#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Silent,
    [switch]$Sysprep,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RemoveApps,
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableWidgets,
    [switch]$HideWidgets,
    [switch]$DisableChat,
    [switch]$HideChat,
    [switch]$ClearStart,
    [switch]$ClearStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$HideGallery,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)


# Show error if current powershell environment does not have LanguageMode set to FullLanguage
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "错误：Win11Debloat 无法在您的系统上运行，powershell 执行受到安全策略的限制" -ForegroundColor Red
    Write-Output ""
    Write-Output "按 Enter 退出..."
    Read-Host | Out-Null
    Exit
}


# Shows application selection form that allows the user to select what apps they want to remove or keep
function ShowAppSelectionForm {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

    # Initialise form objects
    $form = New-Object System.Windows.Forms.Form
    $label = New-Object System.Windows.Forms.Label
    $button1 = New-Object System.Windows.Forms.Button
    $button2 = New-Object System.Windows.Forms.Button
    $selectionBox = New-Object System.Windows.Forms.CheckedListBox
    $loadingLabel = New-Object System.Windows.Forms.Label
    $onlyInstalledCheckBox = New-Object System.Windows.Forms.CheckBox
    $checkUncheckCheckBox = New-Object System.Windows.Forms.CheckBox
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    $global:selectionBoxIndex = -1

    # saveButton eventHandler
    $handler_saveButton_Click=
    {
        $global:SelectedApps = $selectionBox.CheckedItems

        # Create file that stores selected apps if it doesn't exist
        if (!(Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        }

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $global:SelectedApps

        $form.Close()
    }

    # cancelButton eventHandler
    $handler_cancelButton_Click=
    {
        $form.Close()
    }

    $selectionBox_SelectedIndexChanged=
    {
        $global:selectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if ($global:selectionBoxIndex -ne -1) {
                    $topIndex = $global:selectionBoxIndex

                    if ($selectionBox.SelectedIndex -gt $topIndex) {
                        for (($i = ($topIndex)); $i -le $selectionBox.SelectedIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                    elseif ($topIndex -gt $selectionBox.SelectedIndex) {
                        for (($i = ($selectionBox.SelectedIndex)); $i -le $topIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                }
            }
            elseif ($global:selectionBoxIndex -ne $selectionBox.SelectedIndex) {
                $selectionBox.SetItemChecked($selectionBox.SelectedIndex, -not $selectionBox.GetItemChecked($selectionBox.SelectedIndex))
            }
        }
    }

    $check_All=
    {
        for (($i = 0); $i -lt $selectionBox.Items.Count; $i++){
            $selectionBox.SetItemChecked($i, $checkUncheckCheckBox.Checked)
        }
    }

    $load_Apps=
    {
        # Correct the initial state of the form to prevent the .Net maximized form issue
        $form.WindowState = $initialFormWindowState

        # Reset state to default before loading appslist again
        $global:selectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        # Set filePath where Appslist can be found
        $appsFile = "$PSScriptRoot/Appslist.txt"
        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($global:wingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via winget, times out after 10 seconds
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobDone = $job | Wait-Job -TimeOut 10

            if (-not $jobDone) {
                # Show error that the script was unable to get list of apps from winget
                [System.Windows.MessageBox]::Show('无法通过 winget 加载已安装应用程序的列表，某些应用程序可能不会显示在列表中。','错误','Ok','Error')
            }
            else {
                # Add output of job (list of apps) to $listOfApps
                $listOfApps = Receive-Job -Job $job
            }
        }

        # Go through appslist and add items one by one to the selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) {
            $appChecked = $true

            # Remove first # if it exists and set appChecked to false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }

            # Remove any comments from the Appname
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }

            # Remove leading and trailing spaces and `*` characters from Appname
            $app = $app.Trim()
            $appString = $app.Trim('*')

            # Make sure appString is not empty
            if ($appString.length -gt 0) {
                if ($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox is checked, check if app is installed before adding it to selectionBox
                    if (-not ($listOfApps -like ("*$appString*")) -and -not (Get-AppxPackage -Name $app)) {
                        # App is not installed, continue with next item
                        continue
                    }
                    if (($appString -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        # App is not installed, continue with next item
                        continue
                    }
                }

                # Add the app to the selectionBox and set it's checked status
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }

        # Hide loading indicator
        $loadingLabel.Visible = $False

        # Sort selectionBox alphabetically
        $selectionBox.Sorted = $True
    }

    $form.Text = "Win11Debloat 应用程序选择"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "确认"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "取消"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = '勾选要删除的应用程序，取消勾选要保留的应用程序'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = '加载应用程序...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = '仅显示已安装的应用'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = '全部选中/取消选中'
    $checkUncheckCheckBox.add_CheckedChanged($check_All)

    $form.Controls.Add($checkUncheckCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,43)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3
    $selectionBox.add_SelectedIndexChanged($selectionBox_SelectedIndexChanged)
    $selectionBox.add_Click($selectionBox_MouseDown)

    $form.Controls.Add($selectionBox)

    # Save the initial state of the form
    $initialFormWindowState = $form.WindowState

    # Load apps into selectionBox
    $form.add_Load($load_Apps)

    # Focus selectionBox when form opens
    $form.Add_Shown({$form.Activate(); $selectionBox.Focus()})

    # Show the Form
    return $form.ShowDialog()
}


# Returns list of apps from the specified file, it trims the app names and removes any comments
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    # Get list of apps from file at the path provided, and remove them one by one
    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) {
        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        # Remove any spaces before and after the Appname
        $app = $app.Trim()

        $appString = $app.Trim('*')
        $appsList += $appString
    }

    return $appsList
}


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) {
        Write-Output "尝试移除 $app..."

        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            # Use winget to remove OneDrive and Edge
            if ($global:wingetInstalled -eq $false) {
                Write-Host "错误：WinGet 未安装或已过时, $app 无法删除" -ForegroundColor Red
            }
            else {
                # Uninstall app via winget
                Strip-Progress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "93")) {
                    Write-Host "无法通过 Winget 卸载 Microsoft Edge" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "您想强制卸载 Edge 吗? 不推荐! (y/n)" ) -eq 'y') {
                        Write-Output ""
                        ForceRemoveEdge
                    }
                }
            }
        }
        else {
            # Use Remove-AppxPackage to remove all other apps
            $app = '*' + $app + '*'

            # Remove installed app for all existing users
            if ($WinVersion -ge 22000){
                # Windows 11 build 22000 or later
                Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers
            }
            else {
                # Windows 10
                Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers
            }

            # Remove provisioned app from OS image, so the app won't be installed for any new users
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
        }
    }

    Write-Output ""
}


# Forcefully removes Microsoft Edge using it's uninstaller
function ForceRemoveEdge {
    # Based on work from loadstring1 & ave9858
    Write-Output "> 强制卸载 Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (Creating this somehow allows uninstalling edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-Output "运行卸载程序..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "删除剩余文件..."

        $appdata = $([Environment]::GetFolderPath('ApplicationData'))

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$appdata\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$appdata\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths){
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  删除 $path" -ForegroundColor DarkGray
            }
        }

        Write-Output "清理注册表..."

        # Remove ms edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge 已卸载"
    }
    else {
        Write-Output ""
        Write-Host "错误：无法强制卸载 Microsoft Edge，找不到卸载程序" -ForegroundColor Red
    }

    Write-Output ""
}


# Execute provided command and strips progress spinners/bars from console output
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "错误: $($_.Exception.Message)"
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
    }
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-Output $message


    if (!$global:Params.ContainsKey("Sysprep")) {
        reg import "$PSScriptRoot\Regfiles\$path"
    }
    else {
        reg load "HKU\Default" "C:\Users\Default\NTUSER.DAT" | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }

    Write-Output ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-Output "> 重新启动 Windows 资源管理器进程以应用所有更改...（这可能会导致一些闪烁）"

    # Only restart if the powershell process matches the OS architecture
    # Restarting explorer from a 32bit Powershell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem)
    {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "无法重新启动 Windows 资源管理器进程，请手动重新启动您的电脑以应用所有更改。"
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$PSScriptRoot/Start/start2.bin"
    )

    Write-Output "> 从所有用户的开始菜单中删除所有固定的应用程序..."

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "错误：无法清除开始菜单，脚本文件夹中缺少 start2.bin 文件" -ForegroundColor Red
        Write-Output ""
        return
    }

    # Get path to start menu file for all users
    $usersStartMenuPaths = get-childitem -path "C:\Users\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

    # Go through all users and replace the start menu file
    ForEach ($startMenuPath in $usersStartMenuPaths) {
        ReplaceStartMenu "$($startMenuPath.Fullname)\start2.bin" $startMenuTemplate
    }

    # Also replace the start menu file for the default user profile
    $defaultProfile = "C:\Users\default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

    # Create folder if it doesn't exist
    if (-not(Test-Path $defaultProfile)) {
        new-item $defaultProfile -ItemType Directory -Force | Out-Null
        Write-Output "为默认用户创建了 LocalState 文件夹"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultProfile -Force
    Write-Output "替换默认用户配置文件的开始菜单"
    Write-Output ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuBinFile = "C:\Users\$([Environment]::UserName)\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin",
        $startMenuTemplate = "$PSScriptRoot/Start/start2.bin"
    )

    $userName = $startMenuBinFile.Split("\")[2]

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "错误：无法清除开始菜单，脚本文件夹中缺少 start2.bin 文件" -ForegroundColor Red
        return
    }

    # Check if bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuBinFile)) {
        Write-Host "错误：无法清除用户 $userName 的开始菜单, 无法找到 start2.bin 文件" -ForegroundColor Red
        return
    }

    $backupBinFile = $startMenuBinFile + ".bak"

    # Backup current start menu file
    Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Output "为用户 $userName 替换开始菜单"
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # Add key if it doesn't already exist
    if (-not $global:Params.ContainsKey($parameterName)) {
        $global:Params.Add($parameterName, $true)
    }

    # Create or clear file that stores last used settings
    if (!(Test-Path "$PSScriptRoot/SavedSettings")) {
        $null = New-Item "$PSScriptRoot/SavedSettings"
    }
    elseif ($global:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/SavedSettings"
    }

    $global:FirstSelection = $false

    # Create entry and add it to the file
    $entry = "$parameterName#- $message"
    Add-Content -Path "$PSScriptRoot/SavedSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat 脚本 - $title"

    if ($global:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Sysprep 模式)"
    }
    else {
        $fullTitle = "$fullTitle (用户: $Env:UserName)"
    }

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path
    )

    Clear-Host

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {
        Write-Output $line
    }
}


function AwaitKeyToExit {
    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "按任意键退出..."
        $null = [System.Console]::ReadKey()
    }
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ((winget -v) -replace 'v','' -gt 1.4)) {
    $global:wingetInstalled = $true
}
else {
    $global:wingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget 未安装或已过时。这可能会阻止 Win11Debloat 删除某些应用程序。"
        Write-Output ""
        Write-Output "按任意键继续..."
        $null = [System.Console]::ReadKey()
    }
}

# Get current Windows build version to compare against features
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

$global:Params = $PSBoundParameters
$global:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent', 'Sysprep'
$SPParamCount = 0

# Count how many SPParams exist within Params
# This is later used to check if any options were selected
foreach ($Param in $SPParams) {
    if ($global:Params.ContainsKey($Param)) {
        $SPParamCount++
    }
}

# Hide progress bars for app removal, as they block Win11Debloat's output
if (-not ($global:Params.ContainsKey("Verbose"))) {
    $ProgressPreference = 'SilentlyContinue'
}
else {
    Read-Host "详细模式已启用，按 Enter 继续"
    $ProgressPreference = 'Continue'
}

if ($global:Params.ContainsKey("Sysprep")) {
    # Exit script if default user directory or NTUSER.DAT file cannot be found
    if (-not (Test-Path "C:\Users\Default\NTUSER.DAT")) {
        Write-Host "错误：无法在 Sysprep 模式下启动 Win11Debloat，无法找到默认用户文件夹 'C:\Users\Default\'" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Host "错误：Windows 10 不支持 Win11Debloat Sysprep 模式" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
}

# Remove SavedSettings file if it exists and is empty
if ((Test-Path "$PSScriptRoot/SavedSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/SavedSettings")))) {
    Remove-Item -Path "$PSScriptRoot/SavedSettings" -recurse
}

# Only run the app selection form if the 'RunAppConfigurator' parameter was passed to the script
if ($RunAppConfigurator) {
    PrintHeader "应用程序配置器"

    $result = ShowAppSelectionForm

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "应用程序配置器已关闭且未保存。" -ForegroundColor Red
    }
    else {
        Write-Output "您的应用程序选择已保存到脚本根文件夹中的 'CustomAppsList' 文件中。"
    }

    AwaitKeyToExit

    Exit
}

# Change script execution based on provided parameters or user input
if ((-not $global:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or ($SPParamCount -eq $global:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1'
    }
    else {
        # Show menu and wait for user input, loops until valid input is provided
        Do {
            $ModeSelectionMessage = "请选择一个选项 (1/2/3/0)"

            PrintHeader '菜单'

            Write-Output "(1) 默认模式：应用默认设置"
            Write-Output "(2) 自定义模式：根据需要修改脚本"
            Write-Output "(3) 应用程序删除模式：选择并删除应用程序，无需进行其他更改"

            # Only show this option if SavedSettings file exists
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) 应用上次保存的自定义设置"

                $ModeSelectionMessage = "请选择一个选项 (1/2/3/4/0)"
            }

            Write-Output ""
            Write-Output "(0) 显示更多信息"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            # Show information based on user input, Suppress user prompt if Silent parameter was passed
            if ($Mode -eq '0') {
                # Get & print script information from file
                PrintFromFile "$PSScriptRoot/Menus/Info_zh"

                Write-Output ""
                Write-Output "按任意键返回..."
                $null = [System.Console]::ReadKey()
            }
            elseif (($Mode -eq '4')-and -not (Test-Path "$PSScriptRoot/SavedSettings")) {
                $Mode = $null
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4')
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults after confirmation
        '1' {
            # Print the default settings & require userconfirmation, unless Silent parameter was passed
            if (-not $Silent) {
                PrintFromFile "$PSScriptRoot/Menus/DefaultSettings_zh"

                Write-Output ""
                Write-Output "按 Enter 执行脚本或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot'

            PrintHeader '默认模式'

            # Add default parameters if they don't already exist
            foreach ($ParameterName in $DefaultParameterNames) {
                if (-not $global:Params.ContainsKey($ParameterName)){
                    $global:Params.Add($ParameterName, $true)
                }
            }

            # Only add this option for Windows 10 users, if it doesn't already exist
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -and (-not $global:Params.ContainsKey('Hide3dObjects'))) {
                $global:Params.Add('Hide3dObjects', $Hide3dObjects)
            }
        }

        # Custom mode, show & add options based on user input
        '2' {
            # Get current Windows build version to compare against features
            $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

            PrintHeader '自定义模式'

            # Show options for removing apps, only continue on valid input
            Do {
                Write-Host "选项:" -ForegroundColor Yellow
                Write-Host " (n) 不要删除任何应用程序" -ForegroundColor Yellow
                Write-Host " (1) 仅从 'Appslist.txt' 中删除默认选择的过时软件应用程序" -ForegroundColor Yellow
                Write-Host " (2) 删除默认选择的臃肿软件应用程序以及邮件和日历应用程序、开发人员应用程序和游戏应用程序"  -ForegroundColor Yellow
                Write-Host " (3) 选择要删除的应用程序和要保留的应用程序" -ForegroundColor Yellow
                $RemoveAppsInput = Read-Host "你要删除哪些预装的应用程序? (n/1/2/3)"

                # Show app selection form if user entered option 3
                if ($RemoveAppsInput -eq '3') {
                    $result = ShowAppSelectionForm

                    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                        # User cancelled or closed app selection, show error and change RemoveAppsInput so the menu will be shown again
                        Write-Output ""
                        Write-Host "已取消选择，请重试" -ForegroundColor Red

                        $RemoveAppsInput = 'c'
                    }

                    Write-Output ""
                }
            }
            while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3')

            # Select correct option based on user input
            switch ($RemoveAppsInput) {
                '1' {
                    AddParameter 'RemoveApps' '删除默认选择的英国媒体报道软件应用程序'
                }
                '2' {
                    AddParameter 'RemoveApps' '删除默认选择的过时软件应用程序'
                    AddParameter 'RemoveCommApps' '删除邮件、日历和人脉应用'
                    AddParameter 'RemoveW11Outlook' '删除新的 Outlook for Windows 应用程序'
                    AddParameter 'RemoveDevApps' '删除与开发者相关的应用程序'
                    AddParameter 'RemoveGamingApps' '删除 Xbox 应用程序和 Xbox 游戏栏'
                    AddParameter 'DisableDVR' '禁用 Xbox 游戏/屏幕录制'
                }
                '3' {
                    Write-Output "您已选择 $($global:SelectedApps.Count) 要删除的应用程序"

                    AddParameter 'RemoveAppsCustom' "删除 $($global:SelectedApps.Count) 应用程序:"

                    Write-Output ""

                    if ($( Read-Host -Prompt "禁用 Xbox 游戏/屏幕录制? 还可以停止游戏叠加弹出窗口 (y/n)" ) -eq 'y') {
                        AddParameter 'DisableDVR' '禁用 Xbox 游戏/屏幕录制'
                    }
                }
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($global:Params.ContainsKey("Sysprep")) {
                    if ($( Read-Host -Prompt "从所有现有用户和新用户的开始菜单中删除所有固定的应用程序? (y/n)" ) -eq 'y') {
                        AddParameter 'ClearStartAllUsers' '从现有用户和新用户的开始菜单中删除所有固定的应用程序'
                    }
                }
                else {
                    Do {
                        Write-Host "选项:" -ForegroundColor Yellow
                        Write-Host " (n) 不要从开始菜单中删除任何固定的应用程序" -ForegroundColor Yellow
                        Write-Host " (1) 仅为该用户($([Environment]::UserName))从开始菜单中删除所有固定的应用程序" -ForegroundColor Yellow
                        Write-Host " (2) 从所有现有用户和新用户的开始菜单中删除所有固定的应用程序"  -ForegroundColor Yellow
                        $ClearStartInput = Read-Host "从开始菜单中删除所有固定的应用程序? (n/1/2)"
                    }
                    while ($ClearStartInput -ne 'n' -and $ClearStartInput -ne '0' -and $ClearStartInput -ne '1' -and $ClearStartInput -ne '2')

                    # Select correct option based on user input
                    switch ($ClearStartInput) {
                        '1' {
                            AddParameter 'ClearStart' "仅为该用户从开始菜单中删除所有固定的应用程序"
                        }
                        '2' {
                            AddParameter 'ClearStartAllUsers' "从所有现有用户和新用户的开始菜单中删除所有固定的应用程序"
                        }
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "禁用遥测、诊断数据、活动历史记录、应用程序启动跟踪和定向广告? (y/n)" ) -eq 'y') {
                AddParameter 'DisableTelemetry' '禁用遥测、诊断数据、活动历史记录、应用程序启动跟踪和定向广告'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "禁用开始、设置、通知、资源管理器和锁屏中的提示、技巧、建议和广告? (y/n)" ) -eq 'y') {
                AddParameter 'DisableSuggestions' '禁用开始、设置、通知和文件资源管理器中的提示、技巧、建议和广告'
                AddParameter 'DisableLockscreenTips' '禁用锁屏上的提示和技巧'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "在 Windows 搜索中禁用并删除 bing web 搜索、bing AI 和 cortana? (y/n)" ) -eq 'y') {
                AddParameter 'DisableBing' '在 Windows 搜索中禁用并删除 bing web 搜索、bing AI 和 cortana'
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "禁用 Windows Copilot？这适用于所有用户 (y/n)" ) -eq 'y') {
                    AddParameter 'DisableCopilot' '禁用 Windows 副驾驶'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "禁用 Windows 调用快照? 这适用于所有用户 (y/n)" ) -eq 'y') {
                    AddParameter 'DisableRecall' '禁用 Windows 调用快照'
                }
            }

            # Only show this option for Windows 11 users running build 22000 or later
            if ($WinVersion -ge 22000){
                Write-Output ""

                if ($( Read-Host -Prompt "恢复旧的 Windows 10 风格的上下文菜单? (y/n)" ) -eq 'y') {
                    AddParameter 'RevertContextMenu' '恢复旧的 Windows 10 风格的上下文菜单'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "您想要对任务栏和相关服务进行任何更改吗? (y/n)" ) -eq 'y') {
                # Only show these specific options for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   将任务栏按钮与左侧对齐? (y/n)" ) -eq 'y') {
                        AddParameter 'TaskbarAlignLeft' '将任务栏图标左对齐'
                    }

                    # Show options for search icon on taskbar, only continue on valid input
                    Do {
                        Write-Output ""
                        Write-Host "   选项:" -ForegroundColor Yellow
                        Write-Host "    (n) 不变" -ForegroundColor Yellow
                        Write-Host "    (1) 隐藏任务栏中的搜索图标" -ForegroundColor Yellow
                        Write-Host "    (2) 在任务栏上显示搜索图标" -ForegroundColor Yellow
                        Write-Host "    (3) 在任务栏上显示带标签的搜索图标" -ForegroundColor Yellow
                        Write-Host "    (4) 在任务栏上显示搜索框" -ForegroundColor Yellow
                        $TbSearchInput = Read-Host "   隐藏或更改任务栏上的搜索图标? (n/1/2/3/4)"
                    }
                    while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4')

                    # Select correct taskbar search option based on user input
                    switch ($TbSearchInput) {
                        '1' {
                            AddParameter 'HideSearchTb' '隐藏任务栏中的搜索图标'
                        }
                        '2' {
                            AddParameter 'ShowSearchIconTb' '在任务栏上显示搜索图标'
                        }
                        '3' {
                            AddParameter 'ShowSearchLabelTb' '在任务栏上显示带标签的搜索图标'
                        }
                        '4' {
                            AddParameter 'ShowSearchBoxTb' '在任务栏上显示搜索框'
                        }
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   隐藏任务栏上的任务视图按钮? (y/n)" ) -eq 'y') {
                        AddParameter 'HideTaskview' '隐藏任务栏上的任务视图按钮'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   禁用小部件服务并隐藏任务栏中的图标? (y/n)" ) -eq 'y') {
                    AddParameter 'DisableWidgets' '禁用小部件服务并隐藏任务栏中的小部件（新闻和兴趣）图标'
                }

                # Only show this options for Windows users running build 22621 or earlier
                if ($WinVersion -le 22621){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   隐藏任务栏中的聊天（立即开会）图标? (y/n)" ) -eq 'y') {
                        AddParameter 'HideChat' '隐藏任务栏中的聊天（立即开会）图标'
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "您想要对文件资源管理器进行任何更改吗? (y/n)" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   显示隐藏的文件、文件夹和驱动器? (y/n)" ) -eq 'y') {
                    AddParameter 'ShowHiddenFolders' '显示隐藏的文件、文件夹和驱动器'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   显示已知文件类型的文件扩展名? (y/n)" ) -eq 'y') {
                    AddParameter 'ShowKnownFileExt' '显示已知文件类型的文件扩展名'
                }

                # Only show this option for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   从文件资源管理器侧面板隐藏图库部分? (y/n)" ) -eq 'y') {
                        AddParameter 'HideGallery' '从文件资源管理器侧面板隐藏图库部分'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   从文件资源管理器侧面板隐藏重复的可移动驱动器条目，以便它们仅显示在“此电脑”下? (y/n)" ) -eq 'y') {
                    AddParameter 'HideDupliDrive' '从文件资源管理器侧面板隐藏重复的可移动驱动器条目'
                }

                # Only show option for disabling these specific folders for Windows 10 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "您想从文件资源管理器侧面板隐藏任何文件夹吗? (y/n)" ) -eq 'y') {
                        Write-Output ""

                        if ($( Read-Host -Prompt "   从文件资源管理器侧面板隐藏 onedrive 文件夹? (y/n)" ) -eq 'y') {
                            AddParameter 'HideOnedrive' '隐藏文件资源管理器侧面板中的 onedrive 文件夹'
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   从文件资源管理器侧面板隐藏 3D 对象文件夹? (y/n)" ) -eq 'y') {
                            AddParameter 'Hide3dObjects' "隐藏文件资源管理器中 '此电脑' 下的 3D 对象文件夹"
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   从文件资源管理器侧面板隐藏音乐文件夹? (y/n)" ) -eq 'y') {
                            AddParameter 'HideMusic' "在文件资源管理器中隐藏 '此电脑' 下的音乐文件夹"
                        }
                    }
                }
            }

            # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $global:Params.ContainsKey('RevertContextMenu')){
                Write-Output ""

                if ($( Read-Host -Prompt "您想禁用任何上下文菜单选项吗? (y/n)" ) -eq 'y') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   隐藏上下文菜单中的 '包含在库中' 选项? (y/n)" ) -eq 'y') {
                        AddParameter 'HideIncludeInLibrary' "隐藏上下文菜单中的 '包含在库中' 选项"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   隐藏上下文菜单中的 '授予访问权限' 选项? (y/n)" ) -eq 'y') {
                        AddParameter 'HideGiveAccessTo' "隐藏上下文菜单中的 '授予访问权限' 选项"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   隐藏上下文菜单中的 '共享' 选项? (y/n)" ) -eq 'y') {
                        AddParameter 'HideShare' "隐藏上下文菜单中的 '共享' 选项"
                    }
                }
            }

            # Suppress prompt if Silent parameter was passed
            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output ""
                Write-Output "按 Enter 确认您的选择并执行脚本或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            PrintHeader '自定义模式'
        }

        # App removal, remove apps based on user selection
        '3' {
            PrintHeader "应用程序删除"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "您已选择 $($global:SelectedApps.Count) 要删除的应用程序"
                AddParameter 'RemoveAppsCustom' "删除 $($global:SelectedApps.Count) 应用程序:"

                # Suppress prompt if Silent parameter was passed
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output "按 Enter 键删除选定的应用程序或按 CTRL+C 退出..."
                    Read-Host | Out-Null
                    PrintHeader "应用程序删除"
                }
            }
            else {
                Write-Host "选择已取消，没有应用程序被删除" -ForegroundColor Red
                Write-Output ""
            }
        }

        # Load custom options selection from the "SavedSettings" file
        '4' {
            if (-not $Silent) {
                PrintHeader '自定义模式'
                Write-Output "Win11Debloat 将进行以下更改:"

                # Get & print default settings info from file
                Foreach ($line in (Get-Content -Path "$PSScriptRoot/SavedSettings" )) {
                    # Remove any spaces before and after the line
                    $line = $line.Trim()

                    # Check if the line contains a comment
                    if (-not ($line.IndexOf('#') -eq -1)) {
                        $parameterName = $line.Substring(0, $line.IndexOf('#'))

                        # Print parameter description and add parameter to Params list
                        if ($parameterName -eq "RemoveAppsCustom") {
                            if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                                # Apps file does not exist, skip
                                continue
                            }

                            $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
                            Write-Output "- 删除 $($appsList.Count) 应用程序:"
                            Write-Host $appsList -ForegroundColor DarkGray
                        }
                        else {
                            Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                        }

                        if (-not $global:Params.ContainsKey($parameterName)){
                            $global:Params.Add($parameterName, $true)
                        }
                    }
                }

                Write-Output ""
                Write-Output ""
                Write-Output "按 Enter 执行脚本或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            PrintHeader '自定义模式'
        }
    }
}
else {
    PrintHeader '自定义模式'
}


# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $global:Params.Keys.Count) {
    Write-Output "脚本已完成，无需进行任何更改。"

    AwaitKeyToExit
}
else {
    # Execute all selected/provided parameters
    switch ($global:Params.Keys) {
        'RemoveApps' {
            $appsList = ReadAppslistFromFile "$PSScriptRoot/Appslist.txt"
            Write-Output "> 删除默认选择 $($appsList.Count) 应用程序..."
            RemoveApps $appsList
            continue
        }
        'RemoveAppsCustom' {
            if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                Write-Host "> 错误：无法从文件加载自定义应用程序列表，没有删除任何应用程序" -ForegroundColor Red
                Write-Output ""
                continue
            }

            $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
            Write-Output "> 删除 $($appsList.Count) 应用程序..."
            RemoveApps $appsList
            continue
        }
        'RemoveCommApps' {
            Write-Output "> 删除邮件、日历和人脉应用..."

            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            RemoveApps $appsList
            continue
        }
        'RemoveW11Outlook' {
            $appsList = 'Microsoft.OutlookForWindows'
            Write-Output "> 删除新的 Outlook for Windows 应用程序..."
            RemoveApps $appsList
            continue
        }
        'RemoveDevApps' {
            $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
            Write-Output "> 删除与开发者相关的相关应用程序..."
            RemoveApps $appsList
            continue
        }
        'RemoveGamingApps' {
            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            Write-Output "> 删除游戏相关应用..."
            RemoveApps $appsList
            continue
        }
        "ForceRemoveEdge" {
            ForceRemoveEdge
            continue
        }
        'DisableDVR' {
            RegImport "> 禁用 Xbox 游戏/屏幕录制..." "Disable_DVR.reg"
            continue
        }
        'ClearStart' {
            Write-Output "> 从用户$([Environment]::UserName)的开始菜单中删除所有固定的应用程序..."
            ReplaceStartMenu
            Write-Output ""
            continue
        }
        'ClearStartAllUsers' {
            ReplaceStartMenuForAllUsers
            continue
        }
        'DisableTelemetry' {
            RegImport "> 禁用遥测、诊断数据、活动历史记录、应用程序启动跟踪和定向广告..." "Disable_Telemetry.reg"
            continue
        }
        {$_ -in "DisableBingSearches", "DisableBing"} {
            RegImport "> 在 Windows 搜索中禁用 bing 网络搜索、bing AI 和 cortana..." "Disable_Bing_Cortana_In_Search.reg"

            # Also remove the app package for bing search
            $appsList = 'Microsoft.BingSearch'
            RemoveApps $appsList
            continue
        }
        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
            RegImport "> 禁用锁屏上的提示和技巧..." "Disable_Lockscreen_Tips.reg"
            continue
        }
        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
            RegImport "> 禁用 Windows 上的提示、技巧、建议和广告..." "Disable_Windows_Suggestions.reg"
            continue
        }
        'RevertContextMenu' {
            RegImport "> 恢复旧的 Windows 10 样式上下文菜单..." "Disable_Show_More_Options_Context_Menu.reg"
            continue
        }
        'TaskbarAlignLeft' {
            RegImport "> 将任务栏按钮向左对齐..." "Align_Taskbar_Left.reg"

            continue
        }
        'HideSearchTb' {
            RegImport "> 隐藏任务栏上的搜索图标..." "Hide_Search_Taskbar.reg"
            continue
        }
        'ShowSearchIconTb' {
            RegImport "> 将任务栏搜索更改为仅图标..." "Show_Search_Icon.reg"
            continue
        }
        'ShowSearchLabelTb' {
            RegImport "> 将任务栏搜索更改为带标签的图标..." "Show_Search_Icon_And_Label.reg"
            continue
        }
        'ShowSearchBoxTb' {
            RegImport "> 将任务栏搜索更改为搜索框..." "Show_Search_Box.reg"
            continue
        }
        'HideTaskview' {
            RegImport "> 从任务栏隐藏任务视图按钮..." "Hide_Taskview_Taskbar.reg"
            continue
        }
        'DisableCopilot' {
            RegImport "> 禁用 Windows Copilot..." "Disable_Copilot.reg"
            continue
        }
        'DisableRecall' {
            RegImport "> 禁用 Windows 调用快照..." "Disable_AI_Recall.reg"
            continue
        }
        {$_ -in "HideWidgets", "DisableWidgets"} {
            RegImport "> 禁用小部件服务并隐藏任务栏中的小部件图标..." "Disable_Widgets_Taskbar.reg"
            continue
        }
        {$_ -in "HideChat", "DisableChat"} {
            RegImport "> 隐藏任务栏上的聊天图标..." "Disable_Chat_Taskbar.reg"
            continue
        }
        'ShowHiddenFolders' {
            RegImport "> 取消隐藏隐藏的文件、文件夹和驱动器..." "Show_Hidden_Folders.reg"
            continue
        }
        'ShowKnownFileExt' {
            RegImport "> 为已知文件类型启用文件扩展名..." "Show_Extensions_For_Known_File_Types.reg"
            continue
        }
        'HideGallery' {
            RegImport "> 从文件资源管理器导航窗格中隐藏图库部分..." "Hide_Gallery_from_Explorer.reg"
            continue
        }
        'HideDupliDrive' {
            RegImport "> 从文件资源管理器导航窗格隐藏重复的可移动驱动器条目..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
            continue
        }
        {$_ -in "HideOnedrive", "DisableOnedrive"} {
            RegImport "> 从文件资源管理器导航窗格中隐藏 onedrive 文件夹..." "Hide_Onedrive_Folder.reg"
            continue
        }
        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
            RegImport "> 在文件资源管理器导航窗格中隐藏 3D 对象文件夹..." "Hide_3D_Objects_Folder.reg"
            continue
        }
        {$_ -in "HideMusic", "DisableMusic"} {
            RegImport "> 从文件资源管理器导航窗格隐藏音乐文件夹..." "Hide_Music_folder.reg"
            continue
        }
        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
            RegImport "> 在上下文菜单中隐藏 '包含在库中'..." "Disable_Include_in_library_from_context_menu.reg"
            continue
        }
        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
            RegImport "> 在上下文菜单中隐藏 '授予访问权限' ..." "Disable_Give_access_to_context_menu.reg"
            continue
        }
        {$_ -in "HideShare", "DisableShare"} {
            RegImport "> 在上下文菜单中隐藏 '共享' ..." "Disable_Share_from_context_menu.reg"
            continue
        }
    }

    RestartExplorer

    Write-Output ""
    Write-Output ""
    Write-Output ""
    Write-Output "脚本成功完成!"

    AwaitKeyToExit
}
