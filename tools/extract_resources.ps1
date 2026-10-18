param([Parameter(Mandatory=$true)][string]$GameDirectory,[Parameter(Mandatory=$true)][string]$ToolDirectory,[Parameter(Mandatory=$true)][string]$WorkDirectory,[Parameter(Mandatory=$true)][string]$KeySourceFile,[Parameter(Mandatory=$true)][string]$ReferenceManifest)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.Encoding]::UTF8
$game=[IO.Path]::GetFullPath($GameDirectory)
$tool=[IO.Path]::GetFullPath($ToolDirectory)
$root=Join-Path ([IO.Path]::GetFullPath($WorkDirectory)) 'Investigation'
[IO.Directory]::CreateDirectory($root) | Out-Null
Set-Location -LiteralPath $tool
$a=[Reflection.Assembly]::LoadFrom((Join-Path $tool 'TTG Tools.exe'))
[TTG_Tools.MainMenu]::settings=New-Object TTG_Tools.Settings
[TTG_Tools.MainMenu]::settings.ASCII_N=1252
$source=[IO.File]::ReadAllText($KeySourceFile)
$match=[regex]::Match($source,'byte\[\]\s+PN1R\s*=\s*\{([^}]+)\}')
if(-not $match.Success) { throw 'Poker Night Remaster format key not found in official source' }
[byte[]]$gameKey=@($match.Groups[1].Value.Split(',') | ForEach-Object {[Convert]::ToByte($_.Trim().Substring(2),16)})
$flags=[Reflection.BindingFlags]'Static,Public,NonPublic'
$iflags=[Reflection.BindingFlags]'Instance,Public,NonPublic'
$unpackerType=$a.GetType('TTG_Tools.ArchiveUnpacker')
$unpacker=[Runtime.Serialization.FormatterServices]::GetUninitializedObject($unpackerType)
$archiveField=$unpackerType.GetField('ttarch2',$flags)
$readHeader=$unpackerType.GetMethod('ReadHeaderTtarch2',$iflags)
$getFile=$unpackerType.GetMethod('getTtarch2File',$flags)
$entries=New-Object 'Collections.Generic.List[object]'
$archiveHashes=New-Object 'Collections.Generic.List[object]'
$reference=ConvertFrom-Json ([IO.File]::ReadAllText($ReferenceManifest))
foreach($entry in $reference) {
  $path=Join-Path (Join-Path $game 'Archives') $entry.name
  if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256) {throw ('Base game changed: '+$entry.name)}
}
foreach($entry in $reference | Sort-Object name) {
  $archive=Get-Item -LiteralPath (Join-Path (Join-Path $game 'Archives') $entry.name)
  $archiveHashes.Add([pscustomobject]@{name=$archive.Name;bytes=$archive.Length;sha256=(Get-FileHash -LiteralPath $archive.FullName -Algorithm SHA256).Hash.ToLower()})
  if($archive.Extension -ne '.ttarch2') {continue}
  if($archive.Name -match 'Shaders|Tool_txmesh') {continue}
  $archiveField.SetValue($null,(New-Object TTG_Tools.ClassesStructs.Ttarch2Class))
  $readHeader.Invoke($unpacker,@($archive.FullName,$gameKey)) | Out-Null
  $data=$archiveField.GetValue($null)
  if($null -eq $data) {throw ('Archive header failed: '+$archive.Name)}
  $folder=Join-Path $root ('Resources\'+$archive.BaseName)
  [IO.Directory]::CreateDirectory($folder) | Out-Null
  $stream=[IO.File]::OpenRead($archive.FullName)
  $reader=New-Object IO.BinaryReader $stream
  $count=0
  try {
    foreach($f in $data.files) {
      $entry=[ordered]@{archive=$archive.Name;name=$f.fileName;bytes=$f.fileSize;extracted=$false}
      if([IO.Path]::GetExtension($f.fileName) -in @('.font','.landb') -or $f.fileName -eq 'uncensoredText.prop') {
        $target=[IO.Path]::GetFullPath((Join-Path $folder $f.fileName))
        if(-not $target.StartsWith([IO.Path]::GetFullPath($folder)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Resource path escapes target folder'}
        $bytes=$getFile.Invoke($null,@($data,$f,$gameKey,$reader.PSObject.BaseObject))
        if($null -eq $bytes -or $bytes.Length -ne $f.fileSize) {throw ('Resource read failed: '+$f.fileName)}
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        [IO.File]::WriteAllBytes($target,$bytes)
        $entry.extracted=$true
        $entry.path=$target
        $count++
      }
      $entries.Add([pscustomobject]$entry)
    }
  } finally { $reader.Dispose(); $stream.Dispose() }
  [Console]::WriteLine($archive.Name+' files='+$data.files.Length+' extracted='+$count)
}
$utf8=New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $root 'archive-index.json'),(ConvertTo-Json -InputObject @($entries.ToArray()) -Depth 5),$utf8)
[IO.File]::WriteAllText((Join-Path $root 'original-archives-sha256.json'),(ConvertTo-Json -InputObject @($archiveHashes.ToArray()) -Depth 5),$utf8)
[Console]::WriteLine('INDEX_ENTRIES '+$entries.Count)

$prop=@($entries | Where-Object {$_.name -eq 'uncensoredText.prop' -and $_.extracted})
if($prop.Count -ne 1) {throw 'Expected one uncensoredText.prop source'}
$textInput=Join-Path $WorkDirectory 'TextInput'
[IO.Directory]::CreateDirectory($textInput) | Out-Null
Copy-Item -LiteralPath $prop[0].path -Destination (Join-Path $textInput 'uncensoredText.prop') -Force
