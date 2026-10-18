Set-StrictMode -Version 2
$script:OwnedNames=@('CP_pc_Boot_CNProbeBoot.ttarch2','CP_pc_Common_CNProbe.ttarch2','_resdesc_50_Boot_CNProbeBoot.lua','_resdesc_50_Common_CNProbe.lua')

function Get-CnHash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}
function Get-CnManifest([string]$PackageRoot) {
    $m=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $PackageRoot 'manifest.json')))
    if($m.product -ne 'PokerNight-CN' -or [string]$m.app_id -ne '3897800' -or @($m.files).Count -ne 4 -or @($m.supported_builds).Count -eq 0) {
        throw 'INVALID_MANIFEST: 安装包清单不完整，请重新下载完整 ZIP。'
    }
    foreach($name in $script:OwnedNames) {
        $entries=@($m.files | Where-Object {$_.name -ceq $name})
        if($entries.Count -ne 1 -or $entries[0].sha256 -notmatch '^[a-fA-F0-9]{64}$' -or [long]$entries[0].bytes -le 0) {throw 'INVALID_MANIFEST: 资源文件清单无效。'}
    }
    foreach($entry in @($m.known_files)) {
        if($entry.name -cnotin $script:OwnedNames -or $entry.sha256 -notmatch '^[a-fA-F0-9]{64}$') {throw 'INVALID_MANIFEST: 已知版本清单无效。'}
    }
    return $m
}
function Get-CnVdfValue([string]$Text,[string]$Key) {
    $match=[regex]::Match($Text,'"'+[regex]::Escape($Key)+'"\s*"((?:\\.|[^"\\])*)"')
    if($match.Success) {return $match.Groups[1].Value.Replace('\\','\').Replace('\"','"')}
    return $null
}
function Get-CnGameInfo([string]$GamePath) {
    $path=[IO.Path]::GetFullPath($GamePath).TrimEnd('\','/')
    if([IO.Path]::GetFileName($path) -eq 'CelebrityPoker.exe') {$path=Split-Path -Parent $path}
    if([IO.Path]::GetFileName($path) -eq 'Archives') {$path=Split-Path -Parent $path}
    $archives=Join-Path $path 'Archives'
    foreach($file in @('CelebrityPoker.exe','Archives\CP_pc_Boot_compressed.ttarch2','Archives\CP_pc_Common_compressed.ttarch2')) {
        if(-not (Test-Path -LiteralPath (Join-Path $path $file) -PathType Leaf)) {throw ('WRONG_GAME: 请选择包含 CelebrityPoker.exe 和 Archives 的重制版游戏目录。当前目录：'+$path)}
    }
    $steamapps=Split-Path -Parent (Split-Path -Parent $path)
    $manifestPath=Join-Path $steamapps 'appmanifest_3897800.acf'
    $build=$null
    if(Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $text=[IO.File]::ReadAllText($manifestPath)
        $installDir=Get-CnVdfValue $text 'installdir'
        if($installDir -and (Get-CnVdfValue $text 'appid') -eq '3897800') {
            $expected=[IO.Path]::GetFullPath((Join-Path (Join-Path $steamapps 'common') $installDir)).TrimEnd('\','/')
            if($expected -eq $path) {$build=Get-CnVdfValue $text 'buildid'}
        }
    }
    return [pscustomobject]@{Path=$path;Archives=$archives;BuildId=$build;ManifestPath=$manifestPath}
}
function Find-CnGame {
    param([string[]]$SteamRoots)
    $roots=New-Object 'Collections.Generic.List[string]'
    if($PSBoundParameters.ContainsKey('SteamRoots')) {
        foreach($p in $SteamRoots) {if($p){$roots.Add($p)}}
    } else {
        foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
            $entry=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            if($null -ne $entry) {
                foreach($property in @('SteamPath','InstallPath')) {
                    if($entry.PSObject.Properties[$property] -and $entry.$property) {$roots.Add([string]$entry.$property)}
                }
            }
        }
    }
    $libraries=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($root in $roots) {
        if(-not (Test-Path -LiteralPath $root -PathType Container)) {continue}
        [void]$libraries.Add([IO.Path]::GetFullPath($root))
        foreach($relative in @('steamapps\libraryfolders.vdf','config\libraryfolders.vdf')) {
            $vdf=Join-Path $root $relative
            if(-not (Test-Path -LiteralPath $vdf -PathType Leaf)) {continue}
            try {$text=[IO.File]::ReadAllText($vdf)}
            catch {Write-Verbose ('跳过暂时无法读取的 Steam 库配置：'+$vdf);continue}
            foreach($match in [regex]::Matches($text,'"path"\s*"((?:\\.|[^"\\])*)"|"\d+"\s*"([A-Za-z]:[\\/][^"\r\n]*)"')) {
                $value=if($match.Groups[1].Success){$match.Groups[1].Value}else{$match.Groups[2].Value}
                $value=$value.Replace('\\','\').Replace('\"','"')
                try {if(Test-Path -LiteralPath $value -PathType Container) {[void]$libraries.Add([IO.Path]::GetFullPath($value))}}
                catch {Write-Verbose ('跳过无效 Steam 库路径：'+$value)}
            }
        }
    }
    $found=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($library in $libraries) {
        $acf=Join-Path $library 'steamapps\appmanifest_3897800.acf'
        if(-not (Test-Path -LiteralPath $acf -PathType Leaf)) {continue}
        try {
            $text=[IO.File]::ReadAllText($acf)
            $dir=Get-CnVdfValue $text 'installdir'
            if(-not $dir -or (Get-CnVdfValue $text 'appid') -ne '3897800') {continue}
            $info=Get-CnGameInfo (Join-Path (Join-Path $library 'steamapps\common') $dir)
            if($found.Add($info.Path)) {$info}
        } catch {Write-Verbose $_.Exception.Message}
    }
}
function Assert-CnGameClosed([string]$GamePath) {
    $exe=Join-Path $GamePath 'CelebrityPoker.exe'
    foreach($process in @(Get-Process -Name CelebrityPoker -ErrorAction SilentlyContinue)) {
        $runningPath=$null
        try {$runningPath=$process.Path} catch {}
        if(-not $runningPath -or $runningPath -eq $exe) {throw 'GAME_RUNNING: 请完全退出游戏，再重新运行安装或卸载。'}
    }
}
function Get-CnExistingFiles($Info,$Manifest) {
    foreach($name in $script:OwnedNames) {
        $path=Join-Path $Info.Archives $name
        if(-not (Test-Path -LiteralPath $path)) {continue}
        $item=Get-Item -LiteralPath $path -Force
        if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw ('UNKNOWN_FILE: 同名路径不是普通模组文件，已保留：'+$path)}
        $hash=Get-CnHash $path
        $known=@($Manifest.known_files | Where-Object {$_.name -ceq $name -and $_.sha256 -eq $hash})
        if($known.Count -eq 0) {throw ('UNKNOWN_FILE: 发现已修改或来源未知的同名文件，未进行任何替换或删除：'+$path)}
        [pscustomobject]@{Name=$name;Path=$path;Hash=$hash}
    }
}
function Copy-CnPayload([string]$Source,[string]$Destination) {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
}
function Remove-CnTransaction([string]$Path,[string]$Archives) {
    $resolved=[IO.Path]::GetFullPath($Path)
    if((Split-Path -Parent $resolved) -ne [IO.Path]::GetFullPath($Archives) -or [IO.Path]::GetFileName($resolved) -notmatch '^\.cn-[a-f0-9]{16}$') {throw 'Invalid transaction cleanup path'}
    foreach($entry in @(Get-ChildItem -LiteralPath $resolved -Force)) {
        $allowed=@(foreach($n in $script:OwnedNames){'new_'+$n;'backup_'+$n})
        if($entry.Name -cnotin $allowed -or $entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Unexpected transaction content; backup retained'}
        Remove-Item -LiteralPath $entry.FullName -Force -ErrorAction Stop
    }
    Remove-Item -LiteralPath $resolved -ErrorAction Stop
}
function Invoke-CnSetupCore {
    param(
        [Parameter(Mandatory=$true)][string]$PackageRoot,
        [Parameter(Mandatory=$true)][string]$GamePath,
        [ValidateSet('Install','Uninstall')][string]$Action='Install',
        [switch]$VerifyOnly
    )
    $manifest=Get-CnManifest $PackageRoot
    $info=Get-CnGameInfo $GamePath
    if($Action -eq 'Install') {
        if(-not $info.BuildId -or $info.BuildId -notin @($manifest.supported_builds)) {
            throw ('UNSUPPORTED_BUILD: 当前包支持 build '+($manifest.supported_builds -join ', ')+'；检测到 '+$info.BuildId+'。请使用匹配游戏版本的汉化包。')
        }
        foreach($entry in $manifest.files) {
            $source=Join-Path $PackageRoot ('Archives\'+$entry.name)
            if(-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Get-CnHash $source) -ne $entry.sha256 -or (Get-Item -LiteralPath $source).Length -ne [long]$entry.bytes) {
                throw ('PAYLOAD_HASH: 下载包资源缺失或校验失败，请重新解压或下载：'+$entry.name)
            }
        }
    }
    $existing=@(Get-CnExistingFiles $info $manifest)
    if($VerifyOnly) {return [pscustomobject]@{Status='Verified';Action=$Action;GamePath=$info.Path;BuildId=$info.BuildId;Version=$manifest.version}}
    Assert-CnGameClosed $info.Path
    if($Action -eq 'Install' -and $existing.Count -eq 4) {
        $different=@($manifest.files | Where-Object {$entry=$_;@($existing | Where-Object {$_.Name -ceq $entry.name -and $_.Hash -eq $entry.sha256}).Count -ne 1})
        if($different.Count -eq 0) {return [pscustomobject]@{Status='AlreadyInstalled';GamePath=$info.Path;Version=$manifest.version}}
    }
    if($Action -eq 'Uninstall' -and $existing.Count -eq 0) {return [pscustomobject]@{Status='NotInstalled';GamePath=$info.Path;Version=$manifest.version}}
    $transaction=Join-Path $info.Archives ('.cn-'+[Guid]::NewGuid().ToString('N').Substring(0,16))
    if(Test-Path -LiteralPath $transaction) {throw 'Temporary directory collision; please retry'}
    [IO.Directory]::CreateDirectory($transaction) | Out-Null
    $touched=New-Object 'Collections.Generic.List[string]'
    $keepBackup=$false
    try {
        foreach($file in $existing) {
            $backup=Join-Path $transaction ('backup_'+$file.Name)
            Copy-Item -LiteralPath $file.Path -Destination $backup -ErrorAction Stop
            if((Get-CnHash $backup) -ne $file.Hash) {throw 'Backup hash mismatch'}
        }
        if($Action -eq 'Install') {
            foreach($entry in $manifest.files) {
                $staged=Join-Path $transaction ('new_'+$entry.name)
                Copy-Item -LiteralPath (Join-Path $PackageRoot ('Archives\'+$entry.name)) -Destination $staged -ErrorAction Stop
                if((Get-CnHash $staged) -ne $entry.sha256) {throw 'Staged file hash mismatch'}
            }
        }
        Assert-CnGameClosed $info.Path
        $targets=if($Action -eq 'Install') {@($manifest.files | ForEach-Object {$_.name})} else {@($existing | ForEach-Object {$_.Name})}
        foreach($name in $targets) {
            $target=[IO.Path]::GetFullPath((Join-Path $info.Archives $name))
            if((Split-Path -Parent $target) -ne $info.Archives -or $name -cnotin $script:OwnedNames) {throw 'Target escaped Archives'}
            $touched.Add($name)
            if($Action -eq 'Install') {
                Copy-CnPayload (Join-Path $transaction ('new_'+$name)) $target
                $expected=@($manifest.files | Where-Object {$_.name -ceq $name})[0]
                if((Get-CnHash $target) -ne $expected.sha256) {throw ('Installed hash mismatch: '+$name)}
            } else {Remove-Item -LiteralPath $target -ErrorAction Stop}
        }
    } catch {
        $failure=$_
        $restoreErrors=New-Object 'Collections.Generic.List[string]'
        foreach($name in $touched) {
            $target=Join-Path $info.Archives $name
            try {
                $old=@($existing | Where-Object {$_.Name -ceq $name})
                if($old.Count -eq 1) {
                    Copy-Item -LiteralPath (Join-Path $transaction ('backup_'+$name)) -Destination $target -Force -ErrorAction Stop
                    if((Get-CnHash $target) -ne $old[0].Hash) {throw 'Restored hash mismatch'}
                } elseif(Test-Path -LiteralPath $target) {Remove-Item -LiteralPath $target -Force -ErrorAction Stop}
            } catch {$restoreErrors.Add($_.Exception.Message)}
        }
        if($restoreErrors.Count -gt 0) {
            $keepBackup=$true
            throw ('ROLLBACK_FAILED: 操作失败且恢复未完成。请保留备份目录：'+$transaction+'；原因：'+$failure.Exception.Message+'；恢复错误：'+($restoreErrors -join '; '))
        }
        throw $failure
    } finally {
        if(-not $keepBackup) {
            try {Remove-CnTransaction $transaction $info.Archives}
            catch {Write-Warning ('临时备份未完全清理，请保留并记录此目录：'+$transaction+'；'+$_.Exception.Message)}
        }
    }
    $status=if($Action -eq 'Install') {'Installed'} else {'Uninstalled'}
    return [pscustomobject]@{Status=$status;GamePath=$info.Path;Version=$manifest.version}
}
function Invoke-CnSetup {
    param(
        [Parameter(Mandatory=$true)][string]$PackageRoot,
        [Parameter(Mandatory=$true)][string]$GamePath,
        [ValidateSet('Install','Uninstall')][string]$Action='Install',
        [switch]$VerifyOnly
    )
    $path=(Get-CnGameInfo $GamePath).Path.ToUpperInvariant()
    $hasher=[Security.Cryptography.SHA256]::Create()
    try {$key=[BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($path))).Replace('-','')}
    finally {$hasher.Dispose()}
    $mutex=New-Object Threading.Mutex($false,('Local\PokerNightCN_3897800_'+$key))
    $held=$false
    try {
        try {$held=$mutex.WaitOne(0)}
        catch [Threading.AbandonedMutexException] {$held=$true}
        if(-not $held) {throw 'SETUP_BUSY: 另一个安装或卸载进程正在处理此游戏，请等待其结束后再试。'}
        Invoke-CnSetupCore @PSBoundParameters
    } finally {
        if($held) {$mutex.ReleaseMutex()}
        $mutex.Dispose()
    }
}
Export-ModuleMember -Function Find-CnGame,Get-CnGameInfo,Invoke-CnSetup
