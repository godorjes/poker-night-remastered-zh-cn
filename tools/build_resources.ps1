param([Parameter(Mandatory=$true)][string]$ToolDirectory,[Parameter(Mandatory=$true)][string]$WorkDirectory,[Parameter(Mandatory=$true)][string]$KeySourceFile)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.Encoding]::UTF8
$tool=[IO.Path]::GetFullPath($ToolDirectory)
$root=[IO.Path]::GetFullPath($WorkDirectory)
Set-Location -LiteralPath $tool
$a=[Reflection.Assembly]::LoadFrom((Join-Path $tool 'TTG Tools.exe'))
$s=New-Object TTG_Tools.Settings
$s.ASCII_N=1252
$s.unicodeSettings=0
$s.exportRealID=$true
$s.tsvFormat=$true
$s.newTxtFormat=$false
$s.importingOfName=$false
$s.sortSameString=$false
$s.ignoreEmptyStrings=$false
$s.removeBlanksBetweenCjkCharsInImport=$false
$s.replaceDotToChinesePeriodInImport=$false
$s.normalizePunctuationBeforeNewlineInImport=$false
[TTG_Tools.MainMenu]::settings=$s
$flags=[Reflection.BindingFlags]'Static,Public,NonPublic'
$iflags=[Reflection.BindingFlags]'Instance,Public,NonPublic'
function Invoke-Ttg([Reflection.MethodInfo]$Method,[object]$Target,[object[]]$Arguments) {
  for($i=0;$i -lt $Arguments.Length;$i++) {
    if($null -ne $Arguments[$i]) { $Arguments[$i]=$Arguments[$i].PSObject.BaseObject }
  }
  if($null -ne $Target) {$Target=$Target.PSObject.BaseObject}
  return ,($Method.Invoke($Target,$Arguments))
}
$source=[IO.File]::ReadAllText($KeySourceFile)
$match=[regex]::Match($source,'byte\[\]\s+PN1R\s*=\s*\{([^}]+)\}')
if(-not $match.Success) {throw 'Game format key missing'}
[byte[]]$gameKey=@($match.Groups[1].Value.Split(',') | ForEach-Object {[Convert]::ToByte($_.Trim().Substring(2),16)})
$modType=$a.GetType('TTG_Tools.ModCreator')
$pack=$modType.GetMethod('ttarch2BuilderLegacy1132',$flags)
$methods=$a.GetType('TTG_Tools.Methods')
$encryptLua=$methods.GetMethod('encryptLua',$flags)
$decryptLua=$methods.GetMethod('decryptLua',$flags)
$profileType=$a.GetType('TTG_Tools.ModCreator+PokerNightRemasterProfile')
$profile=[Activator]::CreateInstance($profileType,$true)
$layouts=Invoke-Ttg ($profileType.GetMethod('GetLayoutOptions',$iflags)) $profile @()
$layout=@($layouts | Where-Object {$_.DisplayName -eq 'Common'})[0]
if($null -eq $layout) {throw 'Common layout not available'}
$unpackerType=$a.GetType('TTG_Tools.ArchiveUnpacker')
$unpacker=[Runtime.Serialization.FormatterServices]::GetUninitializedObject($unpackerType)
$archiveField=$unpackerType.GetField('ttarch2',$flags)
$readHeader=$unpackerType.GetMethod('ReadHeaderTtarch2',$iflags)
$getFile=$unpackerType.GetMethod('getTtarch2File',$flags)
$index=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'Investigation\archive-index.json')))

$stage=Join-Path $root 'Probes\F_FullTextDraft'
$expected=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $stage 'expected.json')))
$common=Join-Path $stage 'Assets\Common'
$boot=Join-Path $stage 'Assets\Boot'
$package=Join-Path $stage 'Package\Archives'
$check=Join-Path $stage 'Reexport'
foreach($d in @($common,$boot,$package,$check)) {[IO.Directory]::CreateDirectory($d) | Out-Null}
$s.pathForOutputFolder=$common
foreach($font in $expected.fonts) {
  $result=[TTG_Tools.Graphics.FontWorker]::DoWork((Join-Path $stage ('FontInput\'+$font.name)),$false)
  if($result -notlike '*successfully imported*') {throw $result}
  [Console]::WriteLine('FONT_IMPORTED '+$font.name)
}
foreach($name in $expected.boot_fonts) {Copy-Item -LiteralPath (Join-Path $common $name) -Destination (Join-Path $boot $name) -Force}
$texts=New-Object 'Collections.Generic.List[object]'
foreach($property in $expected.landb_counts.PSObject.Properties) {
  $name=$property.Name
  $matches=@($index | Where-Object {$_.name -eq $name})
  if($matches.Count -ne 1) {throw ('Ambiguous source: '+$name)}
  $original=$matches[0].path
  $target=if($name -eq 'ui_boot_english.landb') {$boot} else {$common}
  $text=Join-Path $stage ('Text\'+[IO.Path]::GetFileNameWithoutExtension($name)+'.tsv')
  $s.pathForOutputFolder=$target
  $result=[TTG_Tools.Texts.LandbWorker]::DoWork($original,$text,$false,$gameKey,7)
  if($result -notlike '*successfully imported*') {throw $result}
  $s.pathForOutputFolder=$check
  $result=[TTG_Tools.Texts.LandbWorker]::DoWork((Join-Path $target $name),'',$true,$gameKey,7)
  if($result -notlike '*successfully extracted*') {throw $result}
  $tsv=Join-Path $check ([IO.Path]::GetFileNameWithoutExtension($name)+'.tsv')
  if([IO.File]::ReadAllText($tsv) -cne [IO.File]::ReadAllText($text)) {throw ('Text reexport mismatch: '+$name)}
  if([IO.File]::ReadAllLines($tsv).Length -ne [int]$property.Value) {throw ('Text row count mismatch: '+$name)}
  $texts.Add([pscustomobject]@{name=$name;rows=[int]$property.Value;reexport_identical=$true})
  [Console]::WriteLine('TEXT_ROUNDTRIP '+$name+' '+$property.Value)
}
$worker=New-Object TTG_Tools.ForThreads
$worker.add_ReportForWork([TTG_Tools.ReportHandler]{param($message) [Console]::WriteLine($message)})
$propOriginal=($index | Where-Object {$_.name -eq 'uncensoredText.prop'}).path
$failed=New-Object 'Collections.Generic.List[string]'
$s.pathForOutputFolder=$common
$worker.ImportTXTinPROP((New-Object IO.FileInfo $propOriginal),(New-Object IO.FileInfo (Join-Path $stage 'Text\uncensoredText.txt')),$common,$failed)
if($failed.Count -ne 0) {throw ('Property import failed: '+($failed -join ', '))}
$worker.ExportPROP((New-Object IO.FileInfo (Join-Path $common 'uncensoredText.prop')),'uncensoredText.txt',$check)
$propReexport=[IO.File]::ReadAllText((Join-Path $check 'uncensoredText.txt')).Replace("`r`n","`n")
$propIntended=[IO.File]::ReadAllText((Join-Path $stage 'Text\uncensoredText.txt')).Replace("`r`n","`n")
if($propReexport -cne $propIntended) {throw 'Property text reexport mismatch'}
[Console]::WriteLine('PROP_ROUNDTRIP 56')
$verifiedArchives=New-Object 'Collections.Generic.List[object]'
foreach($choice in @(@{layout='Common';mod='CNProbe';assets=$common;count=35},@{layout='Boot';mod='CNProbeBoot';assets=$boot;count=2})) {
  $selected=@($layouts | Where-Object {$_.DisplayName -eq $choice.layout})[0]
  if($null -eq $selected) {throw ('Layout unavailable: '+$choice.layout)}
  $archiveName=Invoke-Ttg ($profileType.GetMethod('BuildArchiveFileName',$iflags)) $profile @($choice.mod,$selected)
  $luaName=Invoke-Ttg ($profileType.GetMethod('BuildLuaFileName',$iflags)) $profile @($choice.mod,$selected)
  $descriptor=Invoke-Ttg ($profileType.GetMethod('BuildLuaDescriptor',$iflags)) $profile @($choice.mod,$archiveName,$selected)
  $archivePath=Join-Path $package $archiveName
  $luaPath=Join-Path $package $luaName
  Invoke-Ttg $pack $null @($choice.assets,$archivePath,$true,$true,$true,$gameKey,2,$true,$null,$null) | Out-Null
  $descriptorBytes=[Text.Encoding]::UTF8.GetBytes($descriptor)
  [IO.File]::WriteAllBytes($luaPath,(Invoke-Ttg $encryptLua $null @($descriptorBytes,$gameKey,$true,7)))
  $decoded=Invoke-Ttg $decryptLua $null @([IO.File]::ReadAllBytes($luaPath),$gameKey,7)
  if([Convert]::ToBase64String($decoded) -cne [Convert]::ToBase64String($descriptorBytes)) {throw ('Descriptor roundtrip mismatch: '+$luaName)}
  $archiveField.SetValue($null,(New-Object TTG_Tools.ClassesStructs.Ttarch2Class))
  Invoke-Ttg $readHeader $unpacker @($archivePath,$gameKey) | Out-Null
  $data=$archiveField.GetValue($null)
  if($null -eq $data -or $data.files.Length -ne $choice.count) {throw ('Resource count mismatch: '+$archiveName)}
  $stream=[IO.File]::OpenRead($archivePath)
  $reader=New-Object IO.BinaryReader $stream
  $verified=New-Object 'Collections.Generic.List[string]'
  try {
    foreach($f in $data.files) {
      $bytes=Invoke-Ttg $getFile $null @($data,$f,$gameKey,$reader)
      $inputBytes=[IO.File]::ReadAllBytes((Join-Path $choice.assets $f.fileName))
      if([Convert]::ToBase64String($bytes) -cne [Convert]::ToBase64String($inputBytes)) {throw ('Archive mismatch: '+$f.fileName)}
      $verified.Add($f.fileName)
    }
  } finally {$reader.Dispose(); $stream.Dispose()}
  $verifiedArchives.Add([pscustomobject]@{archive=$archiveName;descriptor=$luaName;descriptor_roundtrip=$true;archive_roundtrip=$true;resources=@($verified.ToArray())})
  [Console]::WriteLine('ARCHIVE_VERIFIED '+$archiveName+' '+$verified.Count)
}
$hashes=@(Get-ChildItem -LiteralPath $package -File | ForEach-Object {[pscustomobject]@{name=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()}})
$report=[ordered]@{stage='F_FullTextDraft';buildid='25257439';landb=@($texts.ToArray());prop_rows=56;prop_roundtrip=$true;archives=@($verifiedArchives.ToArray());files=$hashes;runtime_verified=$false;installed=$false}
[IO.File]::WriteAllText((Join-Path $stage 'build-verification.json'),(ConvertTo-Json $report -Depth 8),(New-Object Text.UTF8Encoding $false))
[Console]::WriteLine('FULL_TEXT_BUILD_VERIFIED landb=27 prop=56 resources=37 installed=false runtime_tested=false')
