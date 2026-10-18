param(
    [ValidateSet('Install','Uninstall')][string]$Action='Install',
    [string]$GamePath,
    [switch]$NonInteractive,
    [switch]$VerifyOnly
)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding $false
$packageRoot=Split-Path -Parent $PSScriptRoot
$title='怪诞扑克夜 简体中文汉化'
$exitCode=0

function Select-GameFolder([string]$InitialPath) {
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.Application]::EnableVisualStyles()
    $dialog=New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description='选择 Poker Night 重制版游戏目录（包含 CelebrityPoker.exe 和 Archives）。可从 Steam：管理 → 浏览本地文件，查看目录。'
    $dialog.ShowNewFolderButton=$false
    if($InitialPath) {$dialog.SelectedPath=$InitialPath}
    try {
        if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {return $dialog.SelectedPath}
        return $null
    } finally {$dialog.Dispose()}
}
function Show-SetupMessage([string]$Message,[bool]$IsError=$false) {
    Write-Host $Message
    if(-not $NonInteractive) {
        Add-Type -AssemblyName System.Windows.Forms
        $icon=if($IsError){[Windows.Forms.MessageBoxIcon]::Error}else{[Windows.Forms.MessageBoxIcon]::Information}
        [void][Windows.Forms.MessageBox]::Show($Message,$title,[Windows.Forms.MessageBoxButtons]::OK,$icon)
    }
}
try {
    Import-Module (Join-Path $PSScriptRoot 'Installer.psm1') -Force
    if(-not $GamePath) {
        $found=@(Find-CnGame)
        if($found.Count -eq 1) {
            $GamePath=$found[0].Path
            Write-Host ('找到游戏：'+$GamePath)
        } elseif($NonInteractive) {
            throw 'SELECT_GAME: 未能唯一确定游戏目录，请通过 -GamePath 指定。'
        } else {
            $initial=if($found.Count -gt 0){$found[0].Path}else{$null}
            $GamePath=Select-GameFolder $initial
            if(-not $GamePath) {Write-Host '已取消，游戏文件未改动。';exit 2}
        }
    }
    Write-Host '正在校验汉化文件和游戏版本，请稍候……'
    $result=Invoke-CnSetup -PackageRoot $packageRoot -GamePath $GamePath -Action $Action -VerifyOnly:$VerifyOnly
    if($NonInteractive) {$result | ConvertTo-Json -Compress}
    else {
        $message=switch($result.Status) {
            'Installed' {"汉化安装成功！`r`n`r`n从 Steam 正常启动游戏，并开启 Subtitles（字幕）。以后无需重复安装。"}
            'AlreadyInstalled' {"当前汉化已经安装，无需重复操作。`r`n`r`n从 Steam 正常启动游戏即可。"}
            'Uninstalled' {"汉化已卸载，已移除本模组文件。`r`n原版游戏文件和存档保持不变。"}
            'NotInstalled' {'没有发现本汉化包的已知文件，无需卸载。'}
            'Verified' {'文件与版本校验通过；本次没有修改游戏。'}
        }
        Show-SetupMessage ($message+"`r`n`r`n游戏目录："+$result.GamePath)
    }
} catch {
    $exitCode=1
    $detail=$_.Exception.Message
    if($_.Exception -is [UnauthorizedAccessException] -or $detail -match '拒绝访问|Access.*denied') {
        $detail+="`r`n`r`n游戏目录没有写入权限时，请关闭本窗口，再右键 Install.cmd（卸载则选 Uninstall.cmd），以管理员身份运行。"
    }
    Show-SetupMessage ("操作未完成。`r`n`r`n"+$detail) $true
}
exit $exitCode
