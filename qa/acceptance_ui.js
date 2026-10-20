// Inlined into the self-contained offline checklist by generate-test-pack.py.
const criticalIds = new Set(data.plan.criticalCaseIds);
const evidenceIds = new Set(data.plan.evidenceCaseIds);
const metaFields = ['tester', 'device', 'installed', 'test-date', 'approver', 'approval-platform'];

function approvalPlatform() {
  return $('approval-platform').value || 'Windows';
}

function scopedCases() {
  return data.manual.filter(c => c.platform === 'Both' || c.platform === approvalPlatform());
}

function acceptanceAssessment() {
  const cases = scopedCases();
  const counts = {pending: 0, pass: 0, fail: 0, blocked: 0, na: 0};
  for (const c of cases) counts[safeResult(c.id).status]++;
  const openCore = cases.filter(c => criticalIds.has(c.id) && safeResult(c.id).status !== 'pass').map(c => c.id);
  const missingEvidence = cases.filter(c => evidenceIds.has(c.id) && safeResult(c.id).status === 'pass' && !safeResult(c.id).notes.trim()).map(c => c.id);
  const unexplainedExclusions = cases.filter(c => safeResult(c.id).status === 'na' && !safeResult(c.id).notes.trim()).map(c => c.id);
  const issues = [];
  if (!['Windows', 'ChromeOS'].includes($('approval-platform').value)) {
    issues.push('Select a valid approval platform.');
  }
  if (!$('tester').value.trim() || !$('device').value.trim() || !$('test-date').value) {
    issues.push('Enter tester, device and test date before sign-off.');
  }
  const expectedBuild = data.plan.platformBuilds[approvalPlatform()];
  if ($('installed').value.trim() !== expectedBuild) {
    issues.push('Confirm the exact installed build: expected ' + expectedBuild + ' for ' + approvalPlatform() + '.');
  }
  if (counts.pending) issues.push(counts.pending + ' applicable cases have not been performed.');
  if (counts.fail) issues.push(counts.fail + ' applicable cases failed and need correction/retest.');
  if (counts.blocked) issues.push(counts.blocked + ' applicable cases are blocked; testing is incomplete.');
  if (openCore.length) issues.push('Core functions must pass: ' + compactIds(openCore));
  if (missingEvidence.length) issues.push('Add actual figures or document/backup references for: ' + compactIds(missingEvidence));
  if (unexplainedExclusions.length) issues.push('N/A requires an explicit reason: ' + compactIds(unexplainedExclusions));
  const complete = issues.length === 0;
  const status = complete && !counts.na ? 'ready' : complete ? 'scope-review' : 'not-ready';
  if (counts.na) issues.push(counts.na + ' N/A case(s) remain explicit scope exclusions and require review; they do not prove the feature works.');
  return {status, platform: approvalPlatform(), installedBuild: $('installed').value.trim(), expectedBuild,
    applicable: cases.length, otherPlatform: data.manual.length - cases.length, counts,
    openCore, missingEvidence, unexplainedExclusions, issues};
}

function compactIds(ids) {
  return ids.slice(0, 12).join(', ') + (ids.length > 12 ? ' … (' + ids.length + ' total)' : '');
}

function appendText(parent, tag, text, doc = document) {
  const element = doc.createElement(tag);
  if (text !== undefined) element.textContent = text;
  parent.append(element);
  return element;
}

function appendTable(parent, headers, rows, doc = document) {
  const table = appendText(parent, 'table', undefined, doc);
  const head = appendText(appendText(table, 'thead', undefined, doc), 'tr', undefined, doc);
  for (const header of headers) appendText(head, 'th', header, doc);
  const body = appendText(table, 'tbody', undefined, doc);
  for (const values of rows) {
    const row = appendText(body, 'tr', undefined, doc);
    for (const value of values) appendText(row, 'td', value, doc);
  }
  return table;
}

function updateApproval() {
  const assessment = acceptanceAssessment();
  $('scope-info').textContent = 'Approval scope: ' + assessment.platform + ' build ' + assessment.expectedBuild +
    '. ' + assessment.applicable + ' applicable cases; ' + assessment.otherPlatform +
    ' cases for the other platform excluded. Filters do not change this scope.';
  $('approval-state').dataset.state = assessment.status;
  $('approval-title').textContent = assessment.status === 'ready' ? 'Ready for your sign-off / جاهز للمراجعة والاعتماد' :
    assessment.status === 'scope-review' ? 'Review exclusions before approval / راجع الاستثناءات' :
    'Not ready for approval / الاختبار غير مكتمل أو توجد أعطال';
  $('approval-counts').textContent = Object.entries(assessment.counts).map(([label, count]) => label + ': ' + count).join(' · ');
  $('approval-issues').replaceChildren();
  for (const issue of assessment.issues) appendText($('approval-issues'), 'li', issue);
  if (!assessment.issues.length) appendText($('approval-issues'), 'li', 'All applicable recorded checks passed. Review the evidence and remaining-scope table before signing.');
  $('coverage-rows').replaceChildren();
  for (const group of data.plan.coverage) {
    const cases = scopedCases().filter(c => c.category === group.category);
    const count = status => cases.filter(c => safeResult(c.id).status === status).length;
    const row = appendText($('coverage-rows'), 'tr');
    appendText(row, 'td', group.category + ' — ' + group.screens);
    appendText(row, 'td', count('pass') + ' / ' + cases.length);
    appendText(row, 'td', cases.length ? (count('pending') + count('fail') + count('blocked')) : 'Other platform');
    appendText(row, 'td', count('na'));
  }
}

function initializeAcceptance() {
  for (const phase of data.plan.phases) {
    const link = appendText($('guide-index'), 'a', phase.title);
    link.href = '#walkthrough-' + phase.id;
    const option = appendText($('run-phase'), 'option', phase.title);
    option.value = phase.id;
    const detail = appendText($('walkthrough'), 'details');
    detail.id = 'walkthrough-' + phase.id;
    detail.className = 'walkthrough';
    appendText(detail, 'summary', phase.title);
    const steps = appendText(detail, 'ol');
    for (const step of phase.steps) appendText(steps, 'li', step);
    if (phase.rows) {
      const wrapper = appendText(detail, 'div');
      wrapper.className = 'table-scroll';
      appendTable(wrapper, phase.headers, phase.rows);
    }
    appendText(detail, 'p', 'Related checks: ' + phase.caseIds.join(', ')).className = 'case-links';
    const button = appendText(detail, 'button', 'Show this phase’s checks');
    button.className = 'phase-button';
    button.onclick = () => {
      $('run-phase').value = phase.id;
      $('search').value = '';
      $('category').value = 'all';
      $('platform').value = 'all';
      $('filter-status').value = 'all';
      render();
      $('cases').scrollIntoView({behavior: 'smooth'});
    };
  }
  appendTable($('role-matrix'), data.plan.roles.headers, data.plan.roles.rows);
  appendTable($('remaining-scope'), ['Feature / acceptance limit', 'Current status'], data.plan.remainingScope);
  $('export-approval').onclick = exportApprovalReport;
  $('run-phase').addEventListener('input', render);
}

function exportApprovalReport() {
  const assessment = acceptanceAssessment();
  const doc = document.implementation.createHTMLDocument('ERP acceptance report ' + data.release);
  doc.documentElement.lang = 'en';
  const charset = doc.createElement('meta');
  charset.setAttribute('charset', 'utf-8');
  doc.head.prepend(charset);
  appendText(doc.head, 'style', 'body{font:15px/1.5 system-ui,sans-serif;margin:28px;color:#17233c}table{width:100%;border-collapse:collapse;font-size:12px;table-layout:fixed}td,th{padding:8px;text-align:left;vertical-align:top;border:1px solid #ccc;overflow-wrap:anywhere;white-space:pre-wrap}h1{font-size:24px}h2{font-size:18px}tr{break-inside:avoid}p{white-space:pre-wrap}', doc);
  appendText(doc.body, 'h1', 'ERP acceptance report / تقرير اختبار القبول', doc);
  appendText(doc.body, 'p', 'Generated: ' + new Date().toISOString(), doc);
  appendTable(doc.body, ['Field', 'Recorded value'], [
    ['Platform / installed build', assessment.platform + ' / ' + (assessment.installedBuild || 'Not recorded')],
    ['Tester / device', $('tester').value + ' / ' + $('device').value],
    ['Test date / reviewer', $('test-date').value + ' / ' + $('approver').value],
    ['Readiness recommendation', assessment.status],
    ['Recorded results', JSON.stringify(assessment.counts)],
    ['Other-platform cases', String(assessment.otherPlatform) + ' excluded from this platform scope'],
    ['Automated snapshot', data.release + ': ' + data.automated.filter(t => t.result === 'success' && !t.skipped).length + '/' + data.automated.length + ' passed; captured ' + data.verification.capturedAt],
    ['Automated evidence scope', 'A separate developer-run source snapshot; it does not certify your native device, printer, manual results or a different installed APK build.']
  ], doc);
  appendText(doc.body, 'h2', 'Items preventing approval / exclusions', doc);
  const issues = appendText(doc.body, 'ul', undefined, doc);
  for (const issue of assessment.issues) appendText(issues, 'li', issue, doc);
  if (!assessment.issues.length) appendText(issues, 'li', 'No outstanding checklist items for the declared scope. Human review/signature still required.', doc);
  appendText(doc.body, 'h2', 'Manual evidence', doc);
  const applicable = new Set(scopedCases().map(c => c.id));
  appendTable(doc.body, ['Case / module', 'Expected result', 'Recorded status', 'Actual result / evidence'], data.manual.map(c => [
    c.id + ' · ' + c.title + '\n' + c.category, c.expected,
    applicable.has(c.id) ? safeResult(c.id).status : 'Other platform — out of scope', safeResult(c.id).notes
  ]), doc);
  appendText(doc.body, 'h2', 'Features outside this build', doc);
  appendTable(doc.body, ['Feature', 'Acceptance limit'], data.plan.remainingScope, doc);
  appendText(doc.body, 'p', 'Decision (reviewer to complete):  [ ] Approve stated scope   [ ] Request fixes\nApproved by: ____________________   Date: ____________________\nScope / exclusions accepted: __________________________________________', doc);
  appendText(doc.body, 'p', 'This report records human-entered observations. It cannot inspect the ERP, prove all possible paths correct or certify statutory/accounting compliance. Missing, blocked or failed testing must not be represented as passed.', doc);
  download('ERP-approval-report-' + data.release + '-' + assessment.platform + '.html', '<!doctype html>\n' + doc.documentElement.outerHTML, 'text/html;charset=utf-8');
}
