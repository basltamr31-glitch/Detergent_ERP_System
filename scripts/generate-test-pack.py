#!/usr/bin/env python3
"""Build a self-contained acceptance checklist and actual Flutter-test inventory."""
import argparse, hashlib, json
from datetime import datetime, timezone
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--results',default='build/current_tests.jsonl')
parser.add_argument('--analysis',default='build/chromebook_analysis.log')
parser.add_argument('--output')
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
manual=json.loads((root/'qa/manual_cases.json').read_text(encoding='utf-8'))
results_path=root/args.results
analysis_path=root/args.analysis
analysis_text=analysis_path.read_text(encoding='utf-8-sig',errors='replace')
events=[]
for line in results_path.read_text(encoding='utf-8-sig',errors='replace').splitlines():
    try:
        parsed=json.loads(line)
        if isinstance(parsed,dict): events.append(parsed)
    except json.JSONDecodeError: pass
if not any(e.get('type')=='done' for e in events):
    raise SystemExit('The test run has not completed; preserve results and retry later.')
suites={e['suite']['id']:e['suite'] for e in events if e.get('type')=='suite'}
starts={e['test']['id']:e['test'] for e in events if e.get('type')=='testStart' and not e['test']['name'].startswith('loading ')}
results={e['testID']:e for e in events if e.get('type')=='testDone' and e['testID'] in starts}
automated=[]
for ident,test in starts.items():
    path=Path(suites[test['suiteID']]['path']).resolve()
    relative=path.relative_to(root).as_posix()
    result=results.get(ident,{})
    automated.append({'name':test['name'],'file':relative,'result':result.get('result','incomplete'),'skipped':result.get('skipped',False)})
if len(automated)!=len(results): raise SystemExit('Missing final results for some tests.')
case_ids=[case['id'] for case in manual['cases']]
if not case_ids or len(case_ids)!=len(set(case_ids)):
    raise SystemExit('Manual cases must have unique IDs and contain at least one case.')
if any(case['platform'] not in {'Windows','ChromeOS','Both'} or not case['steps'] or not case['expected'] for case in manual['cases']):
    raise SystemExit('Each manual case needs a supported platform, steps and an expected result.')
verification={
    'capturedAt':datetime.now(timezone.utc).isoformat(),
    'testRunSuccess':next(e['success'] for e in reversed(events) if e.get('type')=='done'),
    'resultsSha256':hashlib.sha256(results_path.read_bytes()).hexdigest(),
    'analysisSha256':hashlib.sha256(analysis_path.read_bytes()).hexdigest(),
    'analysisStatus':'No issues found' if 'No issues found!' in analysis_text else 'Not confirmed clean; review analyzer output',
}
data={'release':manual['version'],'manual':manual['cases'],'preparation':manual['preparation'],'automated':automated,'verification':verification}
blob=json.dumps(data,ensure_ascii=False).replace('</','<'+chr(92)+'/')
template=r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ERP Test Pack __VERSION__</title><style>
:root{color-scheme:light;font:16px/1.55 system-ui,sans-serif;color:#17233c;background:#f3f6fa}body{max-width:1140px;margin:0 auto;padding:28px}header{background:#193963;color:white;padding:26px;border-radius:18px}h1{margin:0;font-size:1.8rem}h2{font-size:1.25rem}p{margin:.55em 0}.muted{color:#52627a}.card,details{background:white;border:1px solid #dde5ef;border-radius:14px;padding:18px;margin-top:16px}.controls,.meta,.stats{display:flex;gap:12px;flex-wrap:wrap;align-items:center}label{display:flex;flex-direction:column;gap:5px}input,select,textarea,button{font:inherit;border:1px solid #bdc9d8;border-radius:8px;padding:9px;background:white;color:#17233c}input,select{max-width:100%}textarea{width:100%;box-sizing:border-box;min-height:84px;resize:vertical}button{cursor:pointer;background:#eaf0f8}button.primary{background:#285b92;color:white;border-color:#285b92}button:hover{filter:brightness(.96)}summary{cursor:pointer;display:flex;gap:10px;align-items:center;flex-wrap:wrap;font-weight:650}.badge{font-size:.8rem;background:#edf2f8;padding:3px 9px;border-radius:20px;font-weight:400}.stats span{background:#edf3fb;padding:7px 12px;border-radius:8px}.case-status{margin-inline-start:auto}.expected{border-inline-start:4px solid #2d7b67;padding:10px 14px;background:#f2faf6}.case-footer{margin-top:14px}ol{padding-inline-start:22px}.small{font-size:.88rem}#storage-warning{color:#8a4200}table{width:100%;border-collapse:collapse;font-size:.9rem;table-layout:fixed}td,th{overflow-wrap:anywhere}td,th{padding:10px;text-align:start;border-bottom:1px solid #e3eaf3}td:first-child{width:60%}a{color:#285b92}progress{width:100%;height:18px}#notification{min-height:1.7em}.toolbar{position:sticky;top:0;z-index:1;background:#f3f6faf5;padding:12px 0;backdrop-filter:blur(8px)}@media(max-width:650px){body{padding:12px}header{padding:18px}.controls>*{flex:1 1 100%}.case-status{margin-inline-start:0}td,th{padding:6px}table{font-size:.8rem}}@media print{body{background:white;color:black}.toolbar,.actions,textarea,input,button,select{display:none!important}details{break-inside:avoid}details>*{display:block!important}header{background:white;color:black;border:1px solid #777}#automated{display:block!important}}
</style></head><body>
<header><h1>ERP Test Pack / ملف اختبار النظام</h1><p id="release"></p><p>Manual acceptance checklist for the installed Windows and ChromeOS Android app.</p></header>
<section class="card"><h2>Before testing</h2><ul id="preparation"></ul><p class="muted">The exact sample-cycle figures assume an empty trial dataset. All manual results begin as Pending. Automated test results are a captured developer-run snapshot; physical Chromebook/printing checks still need your device.</p></section>
<section class="card meta"><label>Tester / المختبر<input id="tester" placeholder="Name or initials"></label><label>Device/model / الجهاز<input id="device" placeholder="Windows PC or Chromebook model"></label><label>Installed build<input id="installed" value="__VERSION__"></label></section>
<section class="toolbar"><div class="stats" id="stats"></div><progress id="progress" value="0" max="100"></progress><div class="controls"><label>Search<input type="search" id="search" placeholder="Find a test or feature"></label><label>Category<select id="category"><option value="all">All categories</option></select></label><label>Platform<select id="platform"><option value="all">Both platforms</option><option>Windows</option><option value="ChromeOS">ChromeOS Android</option></select></label><label>Result<select id="filter-status"><option value="all">All results</option><option value="pending">Pending</option><option value="pass">Pass</option><option value="fail">Fail</option><option value="blocked">Blocked</option><option value="na">Not applicable</option></select></label></div><div class="actions controls" style="margin-top:12px"><button class="primary" id="export-json">Export results JSON</button><button id="export-csv">Export results CSV</button><button id="import-results">Import results</button><button id="print">Print checklist</button><button id="reset">Reset checklist results</button><input type="file" id="import-file" accept="application/json,.json" hidden></div><p id="notification" role="status"></p><p id="storage-warning" class="small"></p></section>
<main id="cases"></main>
<section class="card"><h2>All automated regression tests</h2><p id="auto-summary"></p><p class="muted small">These tests use sample data, temporary stores and mocked platform services where appropriate. They do not prove APK installation, ChromeOS hardware operation, a physical printer, or real power-loss behavior.</p><details id="automated"><summary>Expand the complete automated test inventory</summary><table><thead><tr><th>Test</th><th>Source file</th><th>Result</th></tr></thead><tbody id="auto-tests"></tbody></table></details><p class="small">To rerun the automated suite from the repository with Flutter installed: <code>flutter test --no-pub</code> after dependencies have been installed; run <code>dart analyze lib test</code> for static analysis.</p></section>
<footer class="card small"><p>This file works offline and stores checklist notes in browser storage when available. Export results to preserve them or share a bug report. Reset only clears checklist answers; this file has no connection to the ERP database.</p><p>For a failure, record the test ID, device/build, exact action, actual behavior and error text. Do not record passwords or real customer details.</p><p><a href="https://github.com/basltamr31-glitch/Detergent_ERP_System">Project source</a> · <a href="https://developer.android.com/develop/devices/chromeos/learn/development-environment">Official Chromebook Android installation/testing instructions</a></p></footer>
<script id="test-data" type="application/json">__DATA__</script><script>
'use strict';
const data=JSON.parse(document.getElementById('test-data').textContent), key='erp-checklist-'+data.release;
const $=id=>document.getElementById(id), labels={pending:'Pending / لم يختبر',pass:'Pass / ناجح',fail:'Fail / فشل',blocked:'Blocked / متعذر',na:'Not applicable'};
let state={meta:{},results:{}};try{const old=JSON.parse(localStorage.getItem(key)||'null');if(old&&old.version===data.release)state={meta:old.meta||{},results:old.results||{}}}catch(e){$('storage-warning').textContent='Local saving is unavailable. Export your results before closing this file.'}
function save(){try{localStorage.setItem(key,JSON.stringify({version:data.release,...state}));}catch(e){$('storage-warning').textContent='Local saving is unavailable. Export results before closing.'}updateStats()}
function safeResult(id){const result=state.results[id]||{};return {status:Object.hasOwn(labels,result.status)?result.status:'pending',notes:typeof result.notes==='string'?result.notes:''}}
function updateStats(){const counts={pending:0,pass:0,fail:0,blocked:0,na:0};data.manual.forEach(c=>counts[safeResult(c.id).status]++);$('stats').replaceChildren(...Object.entries(counts).map(([k,v])=>{const s=document.createElement('span');s.textContent=labels[k].split(' / ')[0]+': '+v;return s}));$('progress').value=(data.manual.length-counts.pending)/data.manual.length*100}
function resultExport(){return {format:'erp-test-results',version:data.release,exportedAt:new Date().toISOString(),meta:{...state.meta,installed:$('installed').value,tester:$('tester').value,device:$('device').value},results:Object.fromEntries(data.manual.map(c=>[c.id,{title:c.title,...safeResult(c.id)}]))}}
function download(name,text,type){const url=URL.createObjectURL(new Blob([text],{type})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);$('notification').textContent='Results exported.'}
function csvCell(value){let s=String(value??'');if(/^[\s\uFEFF]*[=+\-@]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"'}
function render(){const q=$('search').value.trim().toLowerCase(),cat=$('category').value,p=$('platform').value,status=$('filter-status').value;$('cases').replaceChildren();let count=0;
for(const c of data.manual){const r=safeResult(c.id);if(cat!=='all'&&cat!==c.category||p!=='all'&&c.platform!=='Both'&&c.platform!==p||status!=='all'&&r.status!==status||q&&!JSON.stringify(c).toLowerCase().includes(q))continue;count++;
const details=document.createElement('details');details.dataset.testId=c.id;const summary=document.createElement('summary'),title=document.createElement('span');title.textContent=c.id+' · '+c.title;const badge=document.createElement('span');badge.className='badge';badge.textContent=c.category+' · '+c.platform;const select=document.createElement('select');select.className='case-status';select.setAttribute('aria-label',c.id+' result');for(const [v,label]of Object.entries(labels)){const option=document.createElement('option');option.value=v;option.textContent=label;select.append(option)}select.value=r.status;select.addEventListener('click',e=>e.stopPropagation());select.addEventListener('change',()=>{state.results[c.id]={...safeResult(c.id),status:select.value};save()});summary.append(title,badge,select);details.append(summary);
const steps=document.createElement('ol');for(const step of c.steps){const li=document.createElement('li');li.textContent=step;steps.append(li)}const expected=document.createElement('p');expected.className='expected';expected.textContent='Expected: '+c.expected;const notes=document.createElement('textarea');notes.setAttribute('aria-label',c.id+' notes');notes.placeholder='Actual result, exact error, device details. Never enter passwords.';notes.value=r.notes;notes.addEventListener('input',()=>{state.results[c.id]={...safeResult(c.id),notes:notes.value};save()});details.append(steps,expected,notes);$('cases').append(details)}if(!count){const empty=document.createElement('p');empty.textContent='No matching tests. Change filters to see other cases.';$('cases').append(empty)}updateStats()}
$('release').textContent='Current version '+data.release+' · '+data.manual.length+' manual cases · '+data.automated.length+' automated tests';
for(const text of data.preparation){const li=document.createElement('li');li.textContent=text;$('preparation').append(li)}for(const cat of [...new Set(data.manual.map(c=>c.category))]){const o=document.createElement('option');o.value=o.textContent=cat;$('category').append(o)}
for(const id of ['tester','device','installed']){if(typeof state.meta[id]==='string')$(id).value=state.meta[id];$(id).addEventListener('input',()=>{state.meta[id]=$(id).value;save()})}for(const id of ['search','category','platform','filter-status'])$(id).addEventListener('input',render);
$('export-json').onclick=()=>download('ERP-test-results-'+data.release+'.json',JSON.stringify(resultExport(),null,2),'application/json');
$('export-csv').onclick=()=>{const rows=[['Test ID','Category','Title','Platform','Result','Notes','Tester','Device','Installed build'],...data.manual.map(c=>[c.id,c.category,c.title,c.platform,safeResult(c.id).status,safeResult(c.id).notes,$('tester').value,$('device').value,$('installed').value])];download('ERP-test-results-'+data.release+'.csv','\ufeff'+rows.map(row=>row.map(csvCell).join(',')).join('\r\n'),'text/csv;charset=utf-8')};
$('import-results').onclick=()=>$('import-file').click();$('import-file').onchange=async()=>{try{const file=$('import-file').files[0];if(!file)return;if(file.size>5*1024*1024)throw Error('Results file exceeds 5 MB.');const imported=JSON.parse(await file.text());if(imported.format!=='erp-test-results'||imported.version!==data.release||typeof imported.results!=='object'||imported.results===null)throw Error('Use a results file for this release.');const results={};for(const c of data.manual){const r=imported.results[c.id];if(r&&Object.hasOwn(labels,r.status))results[c.id]={status:r.status,notes:typeof r.notes==='string'?r.notes.slice(0,20000):''}}state.results=results;if(imported.meta&&typeof imported.meta==='object'){for(const id of ['tester','device','installed'])if(typeof imported.meta[id]==='string'){state.meta[id]=imported.meta[id].slice(0,300);$(id).value=state.meta[id]}}save();render();$('notification').textContent='Results imported.'}catch(e){$('notification').textContent='Import rejected: '+e.message}finally{$('import-file').value=''}};
$('reset').onclick=()=>{if(confirm('Clear checklist answers only? Export results first if you need them.')){state.results={};save();render();$('notification').textContent='Checklist answers reset.'}};
$('print').onclick=()=>{document.querySelectorAll('#cases details').forEach(x=>x.open=true);window.print()};
const passed=data.automated.filter(t=>t.result==='success'&&!t.skipped).length;$('auto-summary').textContent=passed+' passed of '+data.automated.length+' captured tests. Static analysis: '+data.verification.analysisStatus+'. Snapshot: '+data.verification.capturedAt+'.';
for(const test of data.automated){const tr=document.createElement('tr'),name=document.createElement('td'),file=document.createElement('td'),result=document.createElement('td');name.textContent=test.name;const a=document.createElement('a');a.href='https://github.com/basltamr31-glitch/Detergent_ERP_System/blob/master/'+test.file;a.textContent=test.file;file.append(a);result.textContent=test.skipped?'skipped':test.result;tr.append(name,file,result);$('auto-tests').append(tr)}render();
</script></body></html>'''
output=root/(args.output or f'artifacts/ERP_Test_Pack_{manual["version"].split("+")[0]}.html')
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(template.replace('__DATA__',blob).replace('__VERSION__',manual['version']),encoding='utf-8')
(root/'qa/automated_inventory.json').write_text(json.dumps({'version':manual['version'],'verification':verification,'tests':automated},ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Generated {output}: {len(data["manual"])} manual scenarios and {len(automated)} actual automated tests.')
