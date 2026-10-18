import argparse,collections,csv,hashlib,json,pathlib,re,shutil,struct
from font_coverage import cmap_characters
parser=argparse.ArgumentParser()
parser.add_argument('--work-dir',required=True)
parser.add_argument('--catalog',required=True)
parser.add_argument('--font-dir',required=True)
parser.add_argument('--font-license',required=True)
args=parser.parse_args()
ROOT=pathlib.Path(args.work_dir).resolve()
STAGE=ROOT/'Probes/F_FullTextDraft'
SCRIPTS=ROOT/'Scripts'
INV=ROOT/'Investigation'
with pathlib.Path(args.catalog).open(encoding='utf-8-sig',newline='') as handle:
    catalog=list(csv.DictReader(handle,delimiter='\t'))
assert len(catalog)==4614
assert len({(r['file'],r['id']) for r in catalog})==4614
patterns=[r'\{[^{}]*\}',r'\[[^\]]*\]',r'<[^>]*>',r'%(?:[-+0#]*\d*(?:\.\d+)?)[dsfiu]',r'\\[nrt]',r'\^(?:font|glyphScale|color):[^\^]*\^',r'\*{2,}']
for row in catalog:
    assert hashlib.sha256(row['english'].encode('utf-8')).hexdigest()==row['source_sha256']
    assert not row['english'] or row['chinese'],(row['file'],row['id'],'empty translation')
    for pattern in patterns:
        assert re.findall(pattern,row['english'])==re.findall(pattern,row['chinese']),(row['file'],row['id'],pattern)
    assert not any(x in row['chinese'] for x in ['\ufffd','ZZ_TEST','中文测试ABC','字幕测试ABC'])
merged={str(i):r['chinese'] for i,r in enumerate(catalog)}
entries=set(r['english'] for r in catalog)
status=collections.Counter(r['status'] for r in catalog)
def write_ttg(file,rows):
    assert all(len(r)==3 for r in rows)
    assert not any('\n' in value or '\r' in value or '\t' in value for row in rows for value in row)
    file.parent.mkdir(parents=True,exist_ok=True)
    file.write_text('\r\n'.join('\t'.join(r) for r in rows)+'\r\n',encoding='utf-8-sig',newline='')

lookup={(r['file'],r['id']):r for r in catalog}
sources=sorted((ROOT/'TextOutput/landb').glob('*.tsv'))
landb_counts={}
for source in sources:
    name=source.stem+'.landb'
    rows=[line.split('\t') for line in source.read_text(encoding='utf-8-sig').splitlines() if line]
    assert all(len(r)==3 for r in rows),name
    output=[]
    for identifier,actor,english in rows:
        entry=lookup[(name,identifier)]
        assert entry['actor']==actor and entry['english']==english
        output.append([identifier,actor,entry['chinese']])
    write_ttg(STAGE/'Text'/(source.stem+'.tsv'),output)
    landb_counts[name]=len(output)
assert sum(landb_counts.values())==4558 and len(landb_counts)==27

original=(ROOT/'TextInput/uncensoredText.prop').read_bytes()
assert original[:4]==b'6VSM'
p=20+struct.unpack_from('<I',original,16)[0]*12+8+12
assert original[p:p+8]==bytes.fromhex('b4f45a5f606e9ccd');p+=8
count=struct.unpack_from('<I',original,p)[0];p+=4
prop_lines=[]
for n in range(count):
    identifier=original[p:p+8].hex();length=struct.unpack_from('<I',original,p+8)[0];p+=12
    english=original[p:p+length].decode('utf-8');p+=length
    entry=lookup[('uncensoredText.prop',identifier)]
    assert entry['english']==english
    assert '\\n' not in entry['chinese'] and '\\r' not in entry['chinese']
    prop_lines.extend([str(n+1)+')',entry['chinese']])
assert count==56 and p==len(original)
(STAGE/'Text/uncensoredText.txt').write_text('\r\n'.join(prop_lines)+'\r\n',encoding='utf-8-sig',newline='')

index=json.loads((INV/'archive-index.json').read_text(encoding='utf-8'))
font_input=STAGE/'FontInput';font_input.mkdir(parents=True,exist_ok=True)
fonts=[]
for item in index:
    if not item['name'].endswith('.font'):continue
    data=pathlib.Path(item['path']).read_bytes()
    if struct.unpack_from('<I',data,16)[0]!=1:continue
    assert data[20:28]==bytes.fromhex('815337639e4a3a9a')
    name=item['name'];bold='Bold' in name or name=='BelloSmCp.font'
    source=pathlib.Path(args.font_dir)/('NotoSansSC-Bold.otf' if bold else 'NotoSansSC-Regular.otf')
    shutil.copy2(item['path'],font_input/name)
    shutil.copy2(source,font_input/(pathlib.Path(name).stem+'.ttf'))
    fonts.append({'name':name,'source':str(source),'original':item['path'],'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
assert len(fonts)==8
needed={ord(c) for target in merged.values() for c in target if ord(c)>127}
coverage=[]
for source in sorted({f['source'] for f in fonts}):
    available=cmap_characters(pathlib.Path(source).read_bytes())
    missing=sorted(needed-available)
    assert not missing,missing
    coverage.append({'font':source,'required_non_ascii':len(needed),'missing':missing})
shutil.copy2(pathlib.Path(args.font_license),STAGE/'OFL.txt')
(STAGE/'expected.json').write_text(json.dumps({'buildid':'25257439','catalog_rows':len(catalog),'unique_strings':len(entries),'status_counts':dict(status),'landb_counts':landb_counts,'prop_count':56,'fonts':fonts,'boot_fonts':['FuturaLTBook.font'],'glyph_coverage':coverage,'runtime_verified':False,'installation_requested':False,'preserve_running_game':True},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'catalog_rows':len(catalog),'text_files':len(landb_counts),'prop_rows':count,'fonts':len(fonts),'missing_glyphs':0,'catalog_modified':False}))
