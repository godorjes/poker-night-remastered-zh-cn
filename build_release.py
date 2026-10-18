"""Wrap prebuilt CN resources for players; never reads or modifies a game install."""
import argparse,hashlib,json,pathlib,tempfile,zipfile

NAMES=('CP_pc_Boot_CNProbeBoot.ttarch2','CP_pc_Common_CNProbe.ttarch2','_resdesc_50_Boot_CNProbeBoot.lua','_resdesc_50_Common_CNProbe.lua')

def sha(data):return hashlib.sha256(data).hexdigest()

def build(args):
    source=pathlib.Path(__file__).resolve().parent
    payload=pathlib.Path(args.payload_dir).resolve()
    output=pathlib.Path(args.output_dir).resolve()
    output.mkdir(parents=True,exist_ok=True)
    files=[];content={}
    for name in NAMES:
        data=(payload/name).read_bytes()
        if not data:raise ValueError('Empty resource: '+name)
        content['Archives/'+name]=data
        files.append({'name':name,'bytes':len(data),'sha256':sha(data)})
    known={(x['name'],x['sha256']) for x in files}
    if args.known_manifest:
        existing=json.loads(pathlib.Path(args.known_manifest).read_text(encoding='utf-8-sig'))
        for entry in existing['files']:
            if entry['name'] in NAMES:known.add((entry['name'],entry['sha256']))
    manifest={'product':'PokerNight-CN','version':args.version,'app_id':'3897800','supported_builds':[args.build_id],
              'files':files,'known_files':[{'name':n,'sha256':h} for n,h in sorted(known)]}
    content['manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
    for relative in ('Install.cmd','Uninstall.cmd','scripts/Installer.psm1','scripts/Setup.ps1','THIRD-PARTY-NOTICES.txt'):
        data=(source/relative).read_text(encoding='utf-8-sig')
        if relative.endswith(('.psm1','.ps1')):content[relative]=data.replace('\r\n','\n').replace('\n','\r\n').encode('utf-8-sig')
        else:content[relative]=data.replace('\r\n','\n').replace('\n','\r\n').encode('utf-8')
    guide=source/'docs/INSTALL.md'
    readme=(guide if guide.exists() else source/'README.md').read_text(encoding='utf-8')
    content['README_使用说明.txt']=readme.replace('\n','\r\n').encode('utf-8-sig')
    content['licenses/OFL.txt']=pathlib.Path(args.font_license).read_bytes()
    content['licenses/Noto-Copyright.txt']=pathlib.Path(args.font_notice).read_bytes()
    content['SHA256SUMS.txt']=''.join(sha(data)+'  '+name+'\n' for name,data in sorted(content.items())).encode('utf-8')
    root='PokerNight-CN-v'+args.version
    target=output/(root+'-Windows.zip')
    with tempfile.NamedTemporaryFile(prefix='.cn-package-',suffix='.zip',dir=output,delete=False) as temp:
        staging=pathlib.Path(temp.name)
    try:
        with zipfile.ZipFile(staging,'w') as z:
            for name,data in sorted(content.items()):
                compression=zipfile.ZIP_STORED if name.startswith('Archives/') else zipfile.ZIP_DEFLATED
                z.writestr(root+'/'+name,data,compress_type=compression)
        with zipfile.ZipFile(staging) as z:
            assert z.testzip() is None
            assert len(z.namelist())==len(content)
            for name,data in content.items():assert z.read(root+'/'+name)==data
        staging.replace(target)
    finally:
        if staging.exists():staging.unlink()
    digest=sha(target.read_bytes())
    target.with_suffix('.zip.sha256').write_text(digest+'  '+target.name+'\n',encoding='ascii')
    result={'release':str(target),'bytes':target.stat().st_size,'sha256':digest,'entries':len(content),'resource_files':files,'version':args.version,'supported_builds':[args.build_id]}
    (output/(root+'-manifest.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True))
    return target

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--payload-dir',required=True)
    parser.add_argument('--output-dir',required=True)
    parser.add_argument('--font-license',required=True)
    parser.add_argument('--font-notice',required=True)
    parser.add_argument('--known-manifest')
    parser.add_argument('--version',default='0.2.1')
    parser.add_argument('--build-id',default='25257439')
    build(parser.parse_args())
