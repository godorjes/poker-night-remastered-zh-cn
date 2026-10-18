param([Parameter(Mandatory=$true)][string]$TestRoot)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.Encoding]::UTF8
$moduleFile=Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Installer.psm1'
if(-not (Test-Path -LiteralPath $moduleFile)) {throw 'FAIL: portable installer has not been implemented'}
Import-Module $moduleFile -Force
$script:passed=0
$script:failed=0
$names=@('CP_pc_Boot_CNProbeBoot.ttarch2','CP_pc_Common_CNProbe.ttarch2','_resdesc_50_Boot_CNProbeBoot.lua','_resdesc_50_Common_CNProbe.lua')
$utf8=New-Object Text.UTF8Encoding $false
[IO.Directory]::CreateDirectory($TestRoot) | Out-Null
$runRoot=Join-Path ([IO.Path]::GetFullPath($TestRoot)) ('installer-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null

function Assert-True($condition,[string]$message) {if(-not $condition){throw $message}}
function Assert-Throws([scriptblock]$action,[string]$pattern) {
  $caught=$null
  try {&$action | Out-Null} catch {$caught=$_.Exception.Message}
  Assert-True ($null -ne $caught -and $caught -match $pattern) ('Expected error '+$pattern+'; got '+$caught)
}
function Test-Case([string]$name,[scriptblock]$body) {
  try {&$body; $script:passed++;Write-Host ('PASS '+$name)}
  catch {$script:failed++;Write-Host ('FAIL '+$name+' :: '+$_.Exception.ToString()+' STACK '+$_.ScriptStackTrace)}
}
function New-Fixture([string]$name,[string]$build='25257439') {
  $base=Join-Path $runRoot $name
  $package=Join-Path $base '下载包 [中文] & space'
  $library=Join-Path $base '游戏库 [中文] & space'
  $game=Join-Path $library 'steamapps\common\Poker Night at the Inventory Remastered'
  $archives=Join-Path $game 'Archives'
  [IO.Directory]::CreateDirectory((Join-Path $package 'Archives')) | Out-Null
  [IO.Directory]::CreateDirectory($archives) | Out-Null
  [IO.File]::WriteAllText((Join-Path $game 'CelebrityPoker.exe'),'fixture executable',$utf8)
  foreach($n in @('CP_pc_Boot_compressed.ttarch2','CP_pc_Common_compressed.ttarch2')) {[IO.File]::WriteAllText((Join-Path $archives $n),'original-'+$n,$utf8)}
  $manifestText='"AppState" { "appid" "3897800" "installdir" "Poker Night at the Inventory Remastered" "buildid" "'+$build+'" }'
  [IO.File]::WriteAllText((Join-Path $library 'steamapps\appmanifest_3897800.acf'),$manifestText,$utf8)
  $files=@(foreach($n in $names) {
    $p=Join-Path $package ('Archives\'+$n)
    [IO.File]::WriteAllText($p,'translated-'+$n,$utf8)
    [pscustomobject]@{name=$n;bytes=(Get-Item -LiteralPath $p).Length;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
  })
  $m=[ordered]@{product='PokerNight-CN';version='0.2.1';app_id='3897800';supported_builds=@('25257439');files=$files;known_files=@($files | Select-Object name,sha256)}
  [IO.File]::WriteAllText((Join-Path $package 'manifest.json'),(ConvertTo-Json $m -Depth 5),$utf8)
  [pscustomobject]@{Base=$base;Package=$package;Library=$library;Game=$game;Archives=$archives;Manifest=$m}
}
function Snapshot([string]$path) {
  return (@(Get-ChildItem -LiteralPath $path -File -Recurse | Sort-Object FullName | ForEach-Object {$_.FullName.Substring($path.Length)+':'+(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}) -join '|')
}

Test-Case 'fresh install preserves original files and handles Chinese spaces brackets ampersands' {
  $f=New-Fixture 'fresh'
  $old=(Get-FileHash -LiteralPath (Join-Path $f.Archives 'CP_pc_Boot_compressed.ttarch2')).Hash
  $r=Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install
  Assert-True ($r.Status -eq 'Installed') 'install status'
  foreach($n in $names) {Assert-True ((Get-FileHash -LiteralPath (Join-Path $f.Archives $n)).Hash -eq (Get-FileHash -LiteralPath (Join-Path $f.Package ('Archives\'+$n))).Hash) $n}
  Assert-True ((Get-FileHash -LiteralPath (Join-Path $f.Archives 'CP_pc_Boot_compressed.ttarch2')).Hash -eq $old) 'original changed'
  Assert-True (@(Get-ChildItem -LiteralPath $f.Archives).Count -eq 6) 'temporary transaction files remain'
}
Test-Case 'repeat install makes no changes' {
  $f=New-Fixture 'repeat'
  Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install | Out-Null
  $before=Snapshot $f.Game
  $r=Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install
  Assert-True ($r.Status -eq 'AlreadyInstalled' -and (Snapshot $f.Game) -eq $before) 'repeat changed files'
}
Test-Case 'unknown same-name mod stops before any write' {
  $f=New-Fixture 'unknown'
  [IO.File]::WriteAllText((Join-Path $f.Archives $names[1]),'someone else modified this',$utf8)
  $before=Snapshot $f.Game
  Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install} 'UNKNOWN_FILE'
  Assert-True ((Snapshot $f.Game) -eq $before) 'unknown file touched'
}
Test-Case 'corrupt download stops before any write' {
  $f=New-Fixture 'corrupt'
  [IO.File]::AppendAllText((Join-Path $f.Package ('Archives\'+$names[0])),'broken',$utf8)
  $before=Snapshot $f.Game
  Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install} 'PAYLOAD_HASH'
  Assert-True ((Snapshot $f.Game) -eq $before) 'corrupt install changed game'
}
Test-Case 'unsupported build refuses installation but allows removal' {
  $f=New-Fixture 'new-build' '99999999'
  Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install} 'UNSUPPORTED_BUILD'
  foreach($n in $names) {Copy-Item -LiteralPath (Join-Path $f.Package ('Archives\'+$n)) -Destination (Join-Path $f.Archives $n)}
  $r=Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Uninstall
  Assert-True ($r.Status -eq 'Uninstalled' -and @(Get-ChildItem -LiteralPath $f.Archives).Count -eq 2) 'uninstall blocked on newer build'
}
Test-Case 'uninstall preserves original and unrelated files; repeat is harmless' {
  $f=New-Fixture 'uninstall'
  [IO.File]::WriteAllText((Join-Path $f.Archives 'OtherMod.ttarch2'),'unrelated',$utf8)
  $before=Snapshot $f.Game
  Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install | Out-Null
  Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Uninstall | Out-Null
  Assert-True ((Snapshot $f.Game) -eq $before) 'uninstall removed unrelated data'
  $r=Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Uninstall
  Assert-True ($r.Status -eq 'NotInstalled') 'repeat uninstall'
}
Test-Case 'unknown modified file prevents partial uninstall' {
  $f=New-Fixture 'unknown-remove'
  Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install | Out-Null
  [IO.File]::AppendAllText((Join-Path $f.Archives $names[3]),'edited',$utf8)
  $before=Snapshot $f.Game
  Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Uninstall} 'UNKNOWN_FILE'
  Assert-True ((Snapshot $f.Game) -eq $before) 'partial uninstall'
}
Test-Case 'manifest traversal cannot escape game Archives' {
  $f=New-Fixture 'traversal'
  $f.Manifest.files[0].name='..\CelebrityPoker.exe'
  [IO.File]::WriteAllText((Join-Path $f.Package 'manifest.json'),(ConvertTo-Json $f.Manifest -Depth 5),$utf8)
  $before=Snapshot $f.Game
  Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install} 'INVALID_MANIFEST'
  Assert-True ((Snapshot $f.Game) -eq $before) 'traversal wrote outside Archives'
}
Test-Case 'verify-only never modifies game files' {
  $f=New-Fixture 'check'
  $before=Snapshot $f.Game
  $r=Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install -VerifyOnly
  Assert-True ($r.Status -eq 'Verified' -and (Snapshot $f.Game) -eq $before) 'verify-only mutated game'
}
Test-Case 'wrong folder rejected' {
  $f=New-Fixture 'wrong-folder'
  Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Package -Action Install} 'WRONG_GAME'
}
Test-Case 'discover game in a second Steam library' {
  $f=New-Fixture 'discovery'
  $steam=Join-Path $f.Base 'Steam'
  [IO.Directory]::CreateDirectory((Join-Path $steam 'steamapps')) | Out-Null
  $escaped=$f.Library.Replace('\','\\')
  $vdf='"libraryfolders" { "0" { "path" "'+$steam.Replace('\','\\')+'" } "1" { "path" "'+$escaped+'" } }'
  [IO.File]::WriteAllText((Join-Path $steam 'steamapps\libraryfolders.vdf'),$vdf,$utf8)
  $found=@(Find-CnGame -SteamRoots @($steam))
  Assert-True ($found.Count -eq 1 -and $found[0].Path -eq $f.Game) 'library discovery failed'
}
Test-Case 'old recognized probe upgrades and new files are complete' {
  $f=New-Fixture 'upgrade'
  $old=Join-Path $f.Archives $names[1]
  [IO.File]::WriteAllText($old,'old supported CNProbe',$utf8)
  $f.Manifest.known_files+=@([pscustomobject]@{name=$names[1];sha256=(Get-FileHash -LiteralPath $old).Hash.ToLower()})
  [IO.File]::WriteAllText((Join-Path $f.Package 'manifest.json'),(ConvertTo-Json $f.Manifest -Depth 5),$utf8)
  Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install | Out-Null
  Assert-True ((Get-FileHash -LiteralPath $old).Hash -eq (Get-FileHash -LiteralPath (Join-Path $f.Package ('Archives\'+$names[1]))).Hash) 'upgrade did not replace old probe'
}
Test-Case 'mid-copy failure rolls back old version and removes new files' {
  $f=New-Fixture 'rollback'
  $old=Join-Path $f.Archives $names[1]
  [IO.File]::WriteAllText($old,'old version for rollback',$utf8)
  $f.Manifest.known_files+=@([pscustomobject]@{name=$names[1];sha256=(Get-FileHash -LiteralPath $old).Hash.ToLower()})
  [IO.File]::WriteAllText((Join-Path $f.Package 'manifest.json'),(ConvertTo-Json $f.Manifest -Depth 5),$utf8)
  $before=Snapshot $f.Game
  $m=Get-Module Installer
  &$m {
    $script:copyCalls=0
    $script:realCopy=(Get-Item Function:Copy-CnPayload).ScriptBlock
    function script:Copy-CnPayload($Source,$Destination) {
      $script:copyCalls++
      if($script:copyCalls -eq 3){throw 'simulated disk failure'}
      Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
  }
  try {Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install} 'simulated disk failure'}
  finally {&$m {Set-Item Function:script:Copy-CnPayload $script:realCopy}}
  Assert-True ((Snapshot $f.Game) -eq $before) 'rollback did not restore exact state'
}
Test-Case 'portable setup entry point installs from an extracted Chinese path' {
  $f=New-Fixture 'entry-point'
  $scripts=Join-Path $f.Package 'scripts'
  [IO.Directory]::CreateDirectory($scripts) | Out-Null
  $source=Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Setup.ps1'
  Assert-True (Test-Path -LiteralPath $source) 'FAIL: double-click setup entry point has not been implemented'
  Copy-Item -LiteralPath $source -Destination (Join-Path $scripts 'Setup.ps1')
  Copy-Item -LiteralPath $moduleFile -Destination (Join-Path $scripts 'Installer.psm1')
  $output=& (Join-Path $PSHOME 'powershell.exe') -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $scripts 'Setup.ps1') -GamePath $f.Game -Action Install -NonInteractive
  Assert-True ($LASTEXITCODE -eq 0) ('setup failed: '+($output -join ' '))
  Assert-True (@(Get-ChildItem -LiteralPath $f.Archives).Count -eq 6) 'entry point did not install all resources'
  $output=& (Join-Path $PSHOME 'powershell.exe') -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $scripts 'Setup.ps1') -GamePath $f.Game -Action Uninstall -NonInteractive
  Assert-True ($LASTEXITCODE -eq 0 -and @(Get-ChildItem -LiteralPath $f.Archives).Count -eq 2) ('entry uninstall failed: '+($output -join ' '))
}
Test-Case 'unreadable library metadata does not block another Steam installation' {
  $good=New-Fixture 'readable-steam'
  $bad=Join-Path $runRoot 'locked-steam'
  [IO.Directory]::CreateDirectory((Join-Path $bad 'steamapps')) | Out-Null
  $path=Join-Path $bad 'steamapps\libraryfolders.vdf'
  [IO.File]::WriteAllText($path,'locked metadata',$utf8)
  $lock=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
  try {
    $found=@(Find-CnGame -SteamRoots @($bad,$good.Library))
    Assert-True ($found.Count -eq 1 -and $found[0].Path -eq $good.Game) 'unreadable VDF prevented discovery'
  } finally {$lock.Dispose()}
}
Test-Case 'unreadable appmanifest does not block another Steam library' {
  $good=New-Fixture 'readable-acf'
  $bad=New-Fixture 'locked-acf'
  $path=Join-Path $bad.Library 'steamapps\appmanifest_3897800.acf'
  $lock=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
  try {
    $found=@(Find-CnGame -SteamRoots @($bad.Library,$good.Library))
    Assert-True ($found.Count -eq 1 -and $found[0].Path -eq $good.Game) 'unreadable ACF prevented discovery'
  } finally {$lock.Dispose()}
}
Test-Case 'second installer is rejected while another instance is copying files' {
  $f=New-Fixture 'concurrent'
  $token=[Guid]::NewGuid().ToString('N')
  $readyName='Local\CnReady'+$token
  $releaseName='Local\CnRelease'+$token
  $ready=New-Object Threading.EventWaitHandle($false,[Threading.EventResetMode]::ManualReset,$readyName)
  $release=New-Object Threading.EventWaitHandle($false,[Threading.EventResetMode]::ManualReset,$releaseName)
  $worker=[PowerShell]::Create()
  [void]$worker.AddScript({
    param($modulePath,$package,$game,$readyName,$releaseName)
    $ErrorActionPreference='Stop'
    Import-Module $modulePath -Force
    $m=Get-Module Installer
    &$m {
      param($r,$c)
      $script:ready=[Threading.EventWaitHandle]::OpenExisting($r)
      $script:release=[Threading.EventWaitHandle]::OpenExisting($c)
      $script:firstCopy=$true
      function script:Copy-CnPayload($Source,$Destination) {
        if($script:firstCopy) {
          $script:firstCopy=$false
          [void]$script:ready.Set()
          if(-not $script:release.WaitOne(15000)) {throw 'Test synchronization timeout'}
        }
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
      }
    } $readyName $releaseName
    Invoke-CnSetup -PackageRoot $package -GamePath $game -Action Install
  }).AddArgument($moduleFile).AddArgument($f.Package).AddArgument($f.Game).AddArgument($readyName).AddArgument($releaseName)
  $pending=$worker.BeginInvoke()
  try {
    Assert-True ($ready.WaitOne(5000)) 'first installer did not reach copy phase'
    Assert-Throws {Invoke-CnSetup -PackageRoot $f.Package -GamePath $f.Game -Action Install} 'SETUP_BUSY'
  } finally {
    [void]$release.Set()
    try {$first=@($worker.EndInvoke($pending));Assert-True ($first.Count -eq 1 -and $first[0].Status -eq 'Installed') 'first installer did not complete'}
    finally {$worker.Dispose();$ready.Dispose();$release.Dispose()}
  }
  Assert-True (@(Get-ChildItem -LiteralPath $f.Archives).Count -eq 6) 'concurrent installation left partial files'
}
Write-Host ('RESULT passed='+$script:passed+' failed='+$script:failed+' root='+$runRoot)
if($script:failed -ne 0){exit 1}
