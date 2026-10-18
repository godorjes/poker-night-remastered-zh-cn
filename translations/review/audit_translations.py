import json,pathlib,re,collections
root=pathlib.Path(__file__).resolve().parent
entries=json.loads((root/'all_entries.json').read_text(encoding='utf-8'))
merged=json.loads((root/'prefilled.json').read_text(encoding='utf-8'))
for group in ['banter','solos_a','solos_b','core']:
    p=root/'output'/f'{group}.json'
    obj=json.loads(p.read_text(encoding='utf-8'))
    assert not set(obj)&set(merged),group
    merged.update(obj)
reviews=[]
for p in sorted((root/'review').glob('*_review.json')) if (root/'review').exists() else []:
    obj=json.loads(p.read_text(encoding='utf-8'))
    for uid,value in obj.items():
        assert uid in merged and isinstance(value,str),(p.name,uid)
        reviews.append({'uid':uid,'before':merged[uid],'after':value,'review':p.name})
        merged[uid]=value.replace('\r\n',r'\r\n').replace('\r',r'\r').replace('\n',r'\n').replace('\t',r'\t')
expected={x['uid'] for x in entries}
assert set(merged)==expected,{'missing':sorted(expected-set(merged)),'extra':sorted(set(merged)-expected)}
checks={
 'animation':r'\{[^{}]*\}',
 'annotation':r'\[[^\]]*\]',
 'resource':r'<[^>]*>',
 'printf':r'%(?:[-+0#]*\d*(?:\.\d+)?)[dsfiu]',
 'escape':r'\\[nrt]',
 'font':r'\^(?:font|glyphScale|color):[^\^]*\^',
 'censorship':r'\*{2,}',
}
errors=[];numerals=[];english_only=[]
for entry in entries:
    uid=entry['uid'];original=entry['text'];target=merged[uid]
    if original and not target: errors.append({'uid':uid,'check':'empty'})
    if '\ufffd' in target: errors.append({'uid':uid,'check':'replacement character'})
    if any(x in target for x in ['ZZ_TEST','中文测试ABC','字幕测试ABC']):errors.append({'uid':uid,'check':'diagnostic prefix'})
    for name,pattern in checks.items():
        a=re.findall(pattern,original);b=re.findall(pattern,target)
        if a!=b: errors.append({'uid':uid,'check':name,'source':a,'target':b})
    a=re.findall(r'\d+(?:[.,]\d+)*',re.sub(checks['animation'],'',original))
    b=re.findall(r'\d+(?:[.,]\d+)*',re.sub(checks['animation'],'',target))
    if a!=b: numerals.append({'uid':uid,'source_numbers':a,'target_numbers':b,'source':original,'target':target})
    plain=target
    for pattern in checks.values(): plain=re.sub(pattern,'',plain)
    if original and not re.search(r'[\u3400-\u9fff]',plain):english_only.append({'uid':uid,'source':original,'target':target,'refs':entry['refs']})
report={'unique_entries':len(entries),'translations':len(merged),'marker_errors':errors,'numeric_differences':numerals,'english_only':english_only,'review_changes':reviews}
(root/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'merged.json').write_text(json.dumps(merged,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'unique':len(entries),'translations':len(merged),'marker_errors':errors,'numeric_differences':numerals,'english_only_count':len(english_only),'review_corrections':len(reviews)},ensure_ascii=True))
