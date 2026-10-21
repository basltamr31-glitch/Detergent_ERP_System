"""Arabic content and presentation for the offline acceptance artifact.

Machine IDs, result enums, build numbers and the captured evidence stay intact.
Only the generated Arabic view is localized; English source files are unchanged.
"""
import ast
from copy import deepcopy
import html
from html.parser import HTMLParser
import json
import re


def arabic_data(root, original):
    content = json.loads((root / 'qa/ar/cases.json').read_text(encoding='utf-8'))
    plan = json.loads((root / 'qa/ar/plan.json').read_text(encoding='utf-8'))
    automated = json.loads((root / 'qa/ar/automated.json').read_text(encoding='utf-8'))
    data = deepcopy(original)
    ids = {case['id'] for case in data['manual']}
    if ids != set(content['cases']):
        raise ValueError('Arabic manual translations must match every source case ID.')
    categories = {case['category'] for case in data['manual']}
    if categories != set(content['categories']) or categories != set(plan['coverage']):
        raise ValueError('Arabic coverage/category translations must be complete.')
    for case in data['manual']:
        title, steps, expected = content['cases'][case['id']]
        if not title or not steps or not all(steps) or not expected:
            raise ValueError('Incomplete Arabic case: ' + case['id'])
        case.update(title=title, steps=steps, expected=expected,
                    category=content['categories'][case['category']])
    if {phase['id'] for phase in data['plan']['phases']} != set(plan['phases']):
        raise ValueError('Arabic walkthrough phases must match the source.')
    for phase in data['plan']['phases']:
        translated = plan['phases'][phase['id']]
        for field in ['steps', 'rows', 'headers']:
            if len(translated.get(field, [])) != len(phase.get(field, [])):
                raise ValueError('Arabic phase structure differs: ' + phase['id'] + '/' + field)
        phase.update(translated)
    for group in data['plan']['coverage']:
        source = group['category']
        group.update(category=content['categories'][source], screens=plan['coverage'][source])
    if len(plan['roles']['rows']) != len(data['plan']['roles']['rows']):
        raise ValueError('Arabic permission matrix is incomplete.')
    for source, translated in zip(data['plan']['roles']['rows'], plan['roles']['rows']):
        if [{'Yes': 'نعم', 'No': 'لا'}[v] for v in source[1:]] != translated[1:]:
            raise ValueError('Arabic role translation changes permissions.')
    if len(plan['remainingScope']) != len(data['plan']['remainingScope']):
        raise ValueError('Arabic remaining-scope table is incomplete.')
    for field in ['title', 'instructions', 'roles', 'remainingScope']:
        data['plan'][field] = plan[field]
    data['preparation'] = plan['instructions']
    for test in data['automated']:
        name = test['name']
        suffix = re.search(r' at ([0-9.]+) in (en|ar)$', name)
        language = re.search(r' in (en|ar)$', name)
        base = name[:suffix.start()] if suffix else name[:language.start()] if language else name
        if base not in automated:
            raise ValueError('Missing Arabic automated-test title: ' + base)
        title = automated[base]
        if suffix:
            title += ' — عند عرض ' + suffix.group(1).removesuffix('.0')
        if language:
            title += ' — ' + ('بالعربية' if language.group(1) == 'ar' else 'بالإنجليزية')
        test['displayName'] = title
    data['locale'] = 'ar'
    return data


class ArabicHTML(HTMLParser):
    def __init__(self, translations):
        super().__init__(convert_charrefs=False)
        self.translations = translations
        self.parts = []
        self.verbatim = []

    def translate(self, value):
        if value in self.translations:
            return self.translations[value]
        return {'Windows': 'ويندوز', 'ChromeOS': 'كروم بوك'}.get(value, value)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'html':
            attrs.update(lang='ar', dir='rtl')
        for key in ['placeholder', 'title', 'aria-label']:
            if key in attrs:
                attrs[key] = self.translate(attrs[key])
        values = ''.join(' ' + key + ('' if value is None else '="' + html.escape(value, quote=True) + '"')
                         for key, value in attrs.items())
        self.parts.append('<' + tag + values + '>')
        if tag in {'style', 'code'}:
            self.verbatim.append(tag)

    def handle_endtag(self, tag):
        if self.verbatim and self.verbatim[-1] == tag:
            self.verbatim.pop()
        self.parts.append('</' + tag + '>')

    def handle_data(self, data):
        if not self.verbatim:
            stripped = data.strip()
            if stripped:
                data = data.replace(stripped, self.translate(stripped), 1)
        self.parts.append(data)

    def handle_entityref(self, name):
        self.parts.append('&' + name + ';')

    def handle_charref(self, name):
        self.parts.append('&#' + name + ';')

    def handle_decl(self, decl):
        self.parts.append('<!' + decl + '>')

    def handle_comment(self, data):
        self.parts.append('<!--' + data + '-->')


def arabic_template(root, source):
    translations = json.loads((root / 'qa/ar/ui.json').read_text(encoding='utf-8'))
    prefix, scripts = source.split('<script id="test-data"', 1)
    # Explicit option values preserve the shared cross-language result protocol.
    prefix = prefix.replace('<option>Windows</option>', '<option value="Windows">Windows</option>')
    parser = ArabicHTML(translations)
    parser.feed(prefix)
    prefix = ''.join(parser.parts).replace('</style>',
        'body{font-family:"Segoe UI",Tahoma,Arial,sans-serif;line-height:1.8}'
        'code,#installed{direction:ltr;unicode-bidi:isolate}'
        'textarea{direction:rtl} .case-links{direction:ltr;text-align:right}'
        '</style>')
    scripts = '<script id="test-data"' + scripts

    def once(old, new):
        nonlocal scripts
        if scripts.count(old) != 1:
            raise ValueError('Arabic UI source contract changed: ' + old)
        scripts = scripts.replace(old, new)

    once("doc.documentElement.lang = 'en';", "doc.documentElement.lang = 'ar'; doc.documentElement.dir = 'rtl';")
    once(".map(([label, count]) => label + ': ' + count)",
         ".map(([label, count]) => labels[label] + ': ' + count)")
    once("' for ' + approvalPlatform()", "' for ' + platformName(approvalPlatform())")
    once("'Approval scope: ' + assessment.platform", "'Approval scope: ' + platformName(assessment.platform)")
    once("['Platform / installed build', assessment.platform", "['Platform / installed build', platformName(assessment.platform)")
    once("['Readiness recommendation', assessment.status]", "['Readiness recommendation', readinessLabel(assessment.status)]")
    once("JSON.stringify(assessment.counts)", "Object.entries(assessment.counts).map(([status, count]) => labels[status] + ': ' + count).join(' · ')")
    once("? safeResult(c.id).status : 'Other platform — out of scope'",
         "? labels[safeResult(c.id).status] : 'Other platform — out of scope'")
    once("c.category+' · '+c.platform+", "c.category+' · '+platformName(c.platform)+")
    once("c.platform,safeResult(c.id).status,safeResult(c.id).notes",
         "platformName(c.platform),labels[safeResult(c.id).status],safeResult(c.id).notes")
    once("$('test-date').value,approvalPlatform()])", "$('test-date').value,platformName(approvalPlatform())])")
    once("name.textContent=test.name;", "name.textContent=test.displayName||test.name;name.title=test.name;")
    once("result.textContent=test.skipped?'skipped':test.result;", "result.textContent=autoStatus(test.skipped?'skipped':test.result);")
    once("+data.verification.analysisStatus+", "+analysisLabel(data.verification.analysisStatus)+")
    once("const imported=JSON.parse(await file.text());",
         'let imported;try{imported=JSON.parse(await file.text());}catch{throw Error("ملف JSON غير صالح للقراءة.");}')
    once("appendText(row, 'td', count('na'));\n  }\n}",
         "appendText(row, 'td', count('na'));\n  }\n  for(const id of ['release','scope-info','approval-issues','auto-summary']) isolateTechnicalText($(id));\n}")
    once("$('run-phase').addEventListener('input', render);",
         "$('run-phase').addEventListener('input', render); isolateTechnicalText($('walkthrough'));")
    once("  download('ERP-approval-report-'", "  isolateTechnicalText(doc.body);\n  download('ERP-approval-report-'")
    scripts = scripts.replace('text-align:left', 'text-align:start')

    # Replace only complete quoted UI literals. Enum keys, IDs, file paths,
    # selectors and the original evidence payload are not translation targets.
    def translate_literal(match):
        try:
            value = ast.literal_eval(match.group())
        except (ValueError, SyntaxError):
            return match.group()
        return json.dumps(translations[value], ensure_ascii=False) if value in translations else match.group()

    scripts = re.sub(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"", translate_literal, scripts)
    helpers = r'''
function platformName(value){return {Windows:'ويندوز',ChromeOS:'كروم بوك',Both:'المنصتان'}[value]||value;}
function readinessLabel(value){return {'ready':'جاهز للمراجعة والاعتماد','scope-review':'تلزم مراجعة الاستثناءات','not-ready':'غير جاهز للاعتماد'}[value]||value;}
function autoStatus(value){return {success:'ناجح',failure:'فشل',error:'خطأ',skipped:'متجاوز',incomplete:'غير مكتمل'}[value]||value;}
function analysisLabel(value){return value==='No issues found'?'لا توجد ملاحظات':'لم يتأكد خلو التحليل من الملاحظات؛ راجع سجل المحلل';}
function isolateTechnicalText(root){
  if(!root)return;
  const doc=root.ownerDocument,walker=doc.createTreeWalker(root,NodeFilter.SHOW_TEXT),nodes=[];
  while(walker.nextNode())if(!walker.currentNode.parentElement.closest('bdi,script,style,code,textarea'))nodes.push(walker.currentNode);
  const pattern=/[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+|[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(?:Z|[+-][0-9]{2}:[0-9]{2})?|[A-Za-z][A-Za-z0-9_-]*\.(?:json|cmd|md|exe|html|dart)/g;
  for(const node of nodes){
    const text=node.textContent,matches=[...text.matchAll(pattern)];if(!matches.length)continue;
    const fragment=doc.createDocumentFragment();let offset=0;
    for(const match of matches){fragment.append(doc.createTextNode(text.slice(offset,match.index)));const bdi=doc.createElement('bdi');bdi.dir='ltr';bdi.textContent=match[0];fragment.append(bdi);offset=match.index+match[0].length;}
    fragment.append(doc.createTextNode(text.slice(offset)));node.replaceWith(fragment);
  }
}
'''
    scripts = scripts.replace("'use strict';", "'use strict';\n" + helpers, 1)
    return prefix + scripts
