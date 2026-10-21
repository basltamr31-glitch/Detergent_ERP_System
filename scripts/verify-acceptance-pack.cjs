// UI tests use a disposable browser context and synthetic observations only.
// Requires Playwright and Chrome; never connects to the ERP or a real profile.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');

(async () => {
  const input = path.resolve(process.argv[2] || 'artifacts/ERP_Full_Acceptance_1.1.1.html');
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  const context = await browser.newContext({viewport: {width: 1280, height: 900}, acceptDownloads: true});
  const errors = [];
  try {
    const page = await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(input).href);
    const data = JSON.parse(await page.locator('#test-data').textContent());
    const arabic = data.locale === 'ar';
    const importedText = arabic ? 'تم استيراد النتائج.' : 'Results imported.';
    const rejectedText = arabic ? 'رُفض الاستيراد: ' : 'Import rejected';
    assert.equal(await page.locator('html').getAttribute('lang'), arabic ? 'ar' : 'en');
    if (arabic) {
      assert.equal(await page.locator('html').getAttribute('dir'), 'rtl');
      assert(data.manual.every(c => /[\u0600-\u06ff]/.test(c.title) && c.steps.every(step => /[\u0600-\u06ff]/.test(step)) && /[\u0600-\u06ff]/.test(c.expected)));
      assert(data.automated.every(t => /[\u0600-\u06ff]/.test(t.displayName)));
      assert.match(await page.locator('#export-approval').textContent(), /تصدير تقرير الاعتماد/);
      assert.doesNotMatch(await page.locator('body').innerText(), /Before testing|Current version|Expected:|Approval scope:|manual cases|applicable cases/);
      if (process.argv.includes('--screenshots')) {
        const output = path.resolve(__dirname, '../build');
        await fs.mkdir(output, {recursive: true});
        await page.screenshot({path: path.join(output, 'acceptance_ar_preview.png')});
        await page.locator('#walkthrough-base').evaluate(element => {element.open = true;});
        await page.locator('#walkthrough-base').screenshot({path: path.join(output, 'acceptance_ar_cycle.png')});
        await page.locator('#walkthrough-base').evaluate(element => {element.open = false;});
      }
    }
    assert.equal(data.manual.length, 133);
    assert.equal(data.automated.length, 132);
    assert(data.automated.every(test => test.result === 'success' && !test.skipped));
    assert.equal(await page.locator('#cases details').count(), data.manual.length);
    assert.equal(await page.locator('#walkthrough details').count(), 7);
    assert.equal(await page.locator('#coverage-rows tr').count(), 13);
    assert.equal(await page.locator('#auto-tests tr').count(), data.automated.length);
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    assert.equal(await page.evaluate(() => acceptanceAssessment().counts.pass), 0);

    await page.locator('#tester').fill('SYNTHETIC UI TEST — not acceptance evidence');
    await page.locator('#device').fill('Isolated headless test context');
    await page.locator('#test-date').fill('2026-10-20');
    await page.locator('[data-test-id="TC-060"] .case-status').selectOption('fail');
    await page.locator('#platform').selectOption('ChromeOS');
    assert.equal(await page.evaluate(() => acceptanceAssessment().counts.fail), 1, 'Filtering must not hide a Windows-scope failure');
    await page.locator('#platform').selectOption('all');
    await page.locator('#run-phase').selectOption('base');
    assert.equal(await page.locator('#cases details').count(), data.plan.phases.find(p => p.id === 'base').caseIds.length);
    await page.locator('#run-phase').selectOption('all');

    // Synthetic status changes only. No result is written to user/browser profiles.
    await page.evaluate(() => {
      for (const c of scopedCases()) state.results[c.id] = {status: 'pass', notes: 'SYNTHETIC TEST reference, not a real ERP observation'};
      save(); render();
    });
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'ready');
    await page.locator('#installed').fill('1.0.0');
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    await page.locator('#installed').fill('1.1.1+9');
    await page.locator('#test-date').fill('');
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    await page.locator('#test-date').fill('2026-10-20');

    await page.evaluate(() => {state.results['TC-071'].notes = ''; save(); render();});
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    assert.match(await page.locator('#approval-issues').textContent(), /TC-071/);
    await page.evaluate(() => {state.results['TC-071'].notes = 'SYNTHETIC reference'; save(); render();});

    await page.locator('[data-test-id="TC-033"] .case-status').selectOption('na');
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'scope-review');
    await page.evaluate(() => {state.results['TC-033'].notes = ''; save(); render();});
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    await page.evaluate(() => {state.results['TC-033'] = {status: 'pass', notes: 'SYNTHETIC'}; save(); render();});
    await page.locator('[data-test-id="TC-060"] .case-status').selectOption('na');
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready', 'Core sales cannot be excluded from approval');
    for (const status of ['fail', 'blocked', 'pending']) {
      await page.locator('[data-test-id="TC-060"] .case-status').selectOption(status);
      assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    }
    await page.locator('[data-test-id="TC-060"] .case-status').selectOption('pass');
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'ready');
    await page.reload();
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'ready', 'Synthetic UI results persist within the disposable context');

    const download = async id => {
      const pending = page.waitForEvent('download');
      await page.locator('#' + id).click();
      return (await pending).path();
    };
    const exported = JSON.parse(await fs.readFile(await download('export-json'), 'utf8'));
    assert.equal(exported.assessment.status, 'ready');
    assert.equal(Object.keys(exported.results).length, 133);
    const csv = await fs.readFile(await download('export-csv'), 'utf8');
    assert(csv.startsWith('\ufeff'));
    assert.equal(csv.split('\r\n').length, 134);
    assert.match(csv.split('\r\n')[0], arabic ? /منصة الاعتماد/ : /Approval platform/);

    const hostileNote = '<img src=x onerror="window.unsafeApproval=true"> — SYNTHETIC';
    await page.evaluate(note => {state.results['TC-071'].notes = note; save(); render();}, hostileNote);
    const reportPath = await download('export-approval');
    const report = await context.newPage();
    report.on('pageerror', error => errors.push(error.message));
    // Playwright's temporary download path has no .html extension. Parse the
    // downloaded HTML as HTML, as the user's named .html file will be opened.
    await report.setContent(await fs.readFile(reportPath, 'utf8'));
    assert.match(await report.locator('body').textContent(), /SYNTHETIC/);
    assert((await report.locator('body').textContent()).includes(hostileNote));
    assert.equal(await report.locator('img').count(), 0, 'Notes must remain text in the exported report');
    assert.equal(await report.evaluate(() => window.unsafeApproval), undefined);
    assert.match(await report.locator('body').textContent(), arabic ? /منصة أخرى|المنصة الأخرى/ : /other platform|Other platform/);
    if (arabic) {
      assert.equal(await report.locator('html').getAttribute('lang'), 'ar');
      assert.equal(await report.locator('html').getAttribute('dir'), 'rtl');
      assert.match(await report.locator('body').textContent(), /جاهز للمراجعة والاعتماد/);
    }
    await report.close();

    await page.locator('#import-file').setInputFiles({name: 'synthetic.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(exported))});
    await page.waitForFunction(expected => document.getElementById('notification').textContent === expected, importedText);
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'ready');
    if (arabic) {
      const peer = await context.newPage();
      peer.on('pageerror', error => errors.push(error.message));
      const englishFile = input.replace(/_AR\.html$/, '.html');
      assert.notEqual(englishFile, input, 'Arabic artifact must have an _AR suffix for paired-locale testing');
      await peer.goto(pathToFileURL(englishFile).href);
      await peer.locator('#import-file').setInputFiles({name: 'arabic-results.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(exported))});
      await peer.waitForFunction(() => document.getElementById('notification').textContent === 'Results imported.');
      assert.equal(await peer.locator('#approval-state').getAttribute('data-state'), 'ready');
      const englishResults = await peer.evaluate(() => resultExport());
      englishResults.results['TC-071'].notes = 'مرجع عربي تجريبي فقط لاختبار نقل النتائج بين اللغتين';
      await page.locator('#import-file').setInputFiles({name: 'english-results.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(englishResults))});
      await page.waitForFunction(expected => document.getElementById('notification').textContent === expected, importedText);
      assert.equal(await page.evaluate(() => safeResult('TC-071').notes), englishResults.results['TC-071'].notes);
      assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'ready');
      assert.match(await page.locator('[data-test-id="TC-071"] summary').textContent(), /مطابقة دورة الشراء/);
      await peer.close();
    }
    const legacy = structuredClone(exported);
    for (const id of Object.keys(legacy.results)) if (Number(id.slice(3)) > 125) delete legacy.results[id];
    legacy.assessment = {status: 'ready'}; // Imported claims are never trusted.
    await page.locator('#import-file').setInputFiles({name: 'old-125.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(legacy))});
    await page.waitForFunction(expected => document.getElementById('notification').textContent === expected, importedText);
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    assert.equal(await page.evaluate(() => acceptanceAssessment().counts.pending), 8);
    await page.locator('#import-file').setInputFiles({name: 'bad.json', mimeType: 'application/json', buffer: Buffer.from('{"format":"wrong"}')});
    await page.waitForFunction(expected => document.getElementById('notification').textContent.startsWith(expected), rejectedText);

    await page.locator('#approval-platform').selectOption('ChromeOS');
    await page.locator('#installed').fill('1.1.0+8');
    await page.evaluate(() => {
      for (const c of scopedCases()) state.results[c.id] = {status: 'pass', notes: 'SYNTHETIC ChromeOS UI gate test'};
      state.results['TC-120'] = {status: 'fail', notes: 'Other platform'};
      save(); render();
    });
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'ready');
    assert.equal(await page.evaluate(() => acceptanceAssessment().counts.fail), 0);
    assert.match(await page.locator('#scope-info').textContent(), /1.1.0\+8/);

    await page.setViewportSize({width: 390, height: 844});
    const overflow = await page.evaluate(() => ({width: window.innerWidth, actual: document.documentElement.scrollWidth,
      elements: [...document.querySelectorAll('body *')].filter(e => e.getBoundingClientRect().right > window.innerWidth + 1 && !e.closest('.table-scroll')).slice(0, 12).map(e => ({tag: e.tagName, id: e.id, class: e.className, right: e.getBoundingClientRect().right}))}));
    assert(overflow.actual <= overflow.width + 1, 'The page should fit a phone-width viewport: ' + JSON.stringify(overflow));
    page.once('dialog', dialog => dialog.accept());
    await page.locator('#reset').click();
    assert.equal(await page.evaluate(() => acceptanceAssessment().counts.pass), 0);
    assert.equal(await page.locator('#approval-state').getAttribute('data-state'), 'not-ready');
    assert.deepEqual(errors, []);
    console.log('Verified: 133 cases, 132 captured tests, seven walkthroughs, platform-scoped approval gates, evidence/N/A rules, persistence, filters, safe imports/exports, report escaping and narrow layout. All manual observations in this test were synthetic and discarded.');
  } finally {
    await context.close();
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
