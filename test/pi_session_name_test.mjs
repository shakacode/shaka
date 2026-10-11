import assert from 'node:assert/strict';
import { test } from 'node:test';
import sessionName from '../skills/shaka/extensions/pi-session-name.js';

function host(name, entries = [], hasUI = true) {
  let tool;
  let confirms = 0;
  let writes = 0;
  let approval = true;
  const pi = {
    registerTool(value) { tool = value; },
    getSessionName() { return name; },
    setSessionName(value) { name = value; writes++; },
    appendEntry(customType, data) { entries.push({ type: 'custom', customType, data }); },
  };
  const ctx = {
    hasUI,
    sessionManager: { getEntries() { return entries; } },
    ui: { async confirm() { confirms++; return approval; } },
  };
  sessionName(pi);
  return {
    async call(value) { return (await tool.execute('call', value, undefined, undefined, ctx)).details; },
    get confirms() { return confirms; },
    get writes() { return writes; },
    get entries() { return entries; },
    approve(value) { approval = value; },
    manual(value) { name = value; },
  };
}

test('reads the actual current name without changing it', async () => {
  const h = host('My task');
  assert.deepEqual(await h.call({}), { name: 'My task', status: 'read' });
  assert.equal(h.writes, 0);
});

test('names an unnamed session and updates its own title without prompting', async () => {
  const h = host();
  assert.deepEqual(await h.call({ name: 'SHAKA · Fix naming' }), { name: 'SHAKA · Fix naming', status: 'renamed' });
  assert.equal((await h.call({ name: 'SHAKA PR #123 · Fix naming' })).status, 'renamed');
  assert.equal(h.confirms, 0);
});

test('same title is a no-op', async () => {
  const h = host('My task');
  assert.equal((await h.call({ name: 'My task' })).status, 'unchanged');
  assert.equal(h.confirms, 0);
  assert.equal(h.writes, 0);
});

test('asks before replacing an existing user title', async () => {
  const h = host('My title');
  assert.equal((await h.call({ name: 'SHAKA · Fix naming' })).status, 'renamed');
  assert.equal(h.confirms, 1);
});

test('preserves a declined title and does not ask again after reload', async () => {
  const h = host('My title');
  h.approve(false);
  assert.deepEqual(await h.call({ name: 'SHAKA · Fix naming' }), { name: 'My title', status: 'preserved' });
  const resumed = host('My title', h.entries);
  assert.equal((await resumed.call({ name: 'SHAKA PR #123 · Fix naming' })).status, 'preserved');
  assert.equal(resumed.confirms, 0);
  assert.equal(resumed.writes, 0);
});

test('recognizes its own title after reload', async () => {
  const h = host();
  await h.call({ name: 'SHAKA · Fix naming' });
  const resumed = host('SHAKA · Fix naming', h.entries);
  assert.equal((await resumed.call({ name: 'SHAKA PR #123 · Fix naming' })).status, 'renamed');
  assert.equal(resumed.confirms, 0);
});

test('manual changes to an agent title require approval', async () => {
  const h = host();
  await h.call({ name: 'SHAKA · Fix naming' });
  h.manual('My title');
  h.approve(false);
  assert.equal((await h.call({ name: 'SHAKA PR #123 · Fix naming' })).name, 'My title');
  assert.equal(h.confirms, 1);
});

test('without UI it preserves existing user titles but can name an unnamed session', async () => {
  const h = host('My title', [], false);
  assert.equal((await h.call({ name: 'SHAKA · Fix naming' })).status, 'preserved');
  assert.equal(h.confirms, 0);
  const unnamed = host(undefined, [], false);
  assert.equal((await unnamed.call({ name: 'SHAKA · Fix naming' })).status, 'renamed');
});

test('rejects blank and multiline titles', async () => {
  const h = host();
  await assert.rejects(h.call({ name: '  ' }), /single.line/);
  await assert.rejects(h.call({ name: 'one\ntwo' }), /single.line/);
  assert.equal(h.writes, 0);
});
