"""Rebuild translated resources from an owned Steam install; never install them."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,urllib.request

REPO=pathlib.Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir',required=True)
    parser.add_argument('--ttg-dir',required=True)
    parser.add_argument('--work-dir',default=str(REPO/'.work'))
    parser.add_argument('--key-source',help='Optional offline MainMenu.cs from the pinned TTG Tools commit')
    args=parser.parse_args()
    game=pathlib.Path(args.game_dir).resolve();tool=pathlib.Path(args.ttg_dir).resolve();work=pathlib.Path(args.work_dir).resolve()
    if work==game or work.is_relative_to(game) or game.is_relative_to(work):
        raise ValueError('The build workspace and game directory must be separate.')
    if not (tool/'TTG Tools.exe').is_file():raise ValueError('TTG Tools.exe not found')
    work.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env.update(TEMP=str(work/'tmp'),TMP=str(work/'tmp'),PYTHONDONTWRITEBYTECODE='1')
    (work/'tmp').mkdir(exist_ok=True)
    pin=json.loads((REPO/'compatibility/ttg-source.json').read_text(encoding='utf-8'))
    key_source=work/'Investigation/ttg-sources/MainMenu.cs';key_source.parent.mkdir(parents=True,exist_ok=True)
    if args.key_source:data=pathlib.Path(args.key_source).read_bytes()
    elif key_source.exists():data=key_source.read_bytes()
    else:
        with urllib.request.urlopen(pin['url'],timeout=30) as response:data=response.read()
    if sha(data)!=pin['sha256']:raise ValueError('Pinned TTG source checksum mismatch')
    key_source.write_bytes(data)
    (work/'Translations').mkdir(exist_ok=True)
    shutil.copy2(REPO/'translations/catalog.tsv',work/'Translations/catalog.tsv')
    ps=pathlib.Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'
    def powershell(script,*parameters):
        subprocess.run([str(ps),'-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(REPO/'tools'/script),*map(str,parameters)],env=env,check=True)
    powershell('extract_resources.ps1','-GameDirectory',game,'-ToolDirectory',tool,'-WorkDirectory',work,'-KeySourceFile',key_source,'-ReferenceManifest',REPO/'compatibility/base-game.json')
    powershell('export_text.ps1','-ToolDirectory',tool,'-WorkDirectory',work)
    subprocess.run([sys.executable,str(REPO/'tools/prepare_inputs.py'),'--work-dir',str(work),'--catalog',str(REPO/'translations/catalog.tsv'),'--font-dir',str(REPO/'assets/fonts'),'--font-license',str(REPO/'licenses/OFL.txt')],env=env,check=True)
    powershell('build_resources.ps1','-ToolDirectory',tool,'-WorkDirectory',work,'-KeySourceFile',key_source)
    print(json.dumps({'payload_dir':str(work/'Probes/F_FullTextDraft/Package/Archives'),'verification':str(work/'Probes/F_FullTextDraft/build-verification.json'),'game_modified':False},ensure_ascii=True))

if __name__=='__main__':main()
