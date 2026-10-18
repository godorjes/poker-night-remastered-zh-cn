param([Parameter(Mandatory=$true)][string]$ToolDirectory,[Parameter(Mandatory=$true)][string]$WorkDirectory)
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
$textOut=Join-Path $root 'TextOutput\landb'
$roundtrip=Join-Path $root 'Investigation\roundtrip\landb'
[IO.Directory]::CreateDirectory($textOut) | Out-Null
[IO.Directory]::CreateDirectory($roundtrip) | Out-Null
$index=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'Investigation\archive-index.json')))
$results=New-Object 'Collections.Generic.List[object]'
foreach($entry in $index | Where-Object {$_.name -like '*.landb'}) {
  $s.pathForOutputFolder=$textOut
  $result=[TTG_Tools.Texts.LandbWorker]::DoWork($entry.path,'',$true,$null,7)
  [Console]::WriteLine($result)
  $tsv=Join-Path $textOut ([IO.Path]::GetFileNameWithoutExtension($entry.name)+'.tsv')
  if(-not (Test-Path -LiteralPath $tsv)) {
    $results.Add([pscustomobject]@{name=$entry.name;status=$result;identical=$null;rows=0})
    continue
  }
  $s.pathForOutputFolder=$roundtrip
  $result=[TTG_Tools.Texts.LandbWorker]::DoWork($entry.path,$tsv,$false,$null,7)
  $rebuilt=Join-Path $roundtrip $entry.name
  if(-not (Test-Path -LiteralPath $rebuilt)) {throw $result}
  $same=(Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $rebuilt -Algorithm SHA256).Hash
  $rows=[IO.File]::ReadAllLines($tsv).Length
  $results.Add([pscustomobject]@{name=$entry.name;status=$result;identical=$same;rows=$rows;source=$entry.path;tsv=$tsv})
  [Console]::WriteLine('  ROUNDTRIP '+$same+' ROWS '+$rows)
}
[IO.File]::WriteAllText((Join-Path $root 'Investigation\landb-roundtrip-results.json'),(ConvertTo-Json -InputObject @($results.ToArray()) -Depth 5),(New-Object Text.UTF8Encoding $false))
