'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test, after } = require('node:test');

const repo = path.resolve(__dirname, '../..');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chatvardage-env-'));
after(() => fs.rmSync(root, { recursive: true, force: true }));

const secretNames = [
  'POSTGRES_SUPERPASS', 'AUTH_DB_PASSWORD', 'ROOMS_DB_PASSWORD',
  'MESSAGES_DB_PASSWORD', 'CONFIG_DB_PASSWORD', 'REDIS_PASSWORD',
  'JWT_SECRET', 'INTERNAL_SERVICE_TOKEN', 'DASHBOARD_COOKIE_SECRET',
  'DASHBOARD_SESSION_SECRET',
];

function fixture({ crlf = false, missing } = {}) {
  const dir = fs.mkdtempSync(path.join(root, 'case-'));
  fs.mkdirSync(path.join(dir, 'scripts'));
  fs.copyFileSync(path.join(repo, 'scripts/generer-env.sh'), path.join(dir, 'scripts/generer-env.sh'));
  let template = fs.readFileSync(path.join(repo, '.env.example'), 'utf8');
  if (missing) template = template.split(/\r?\n/).filter(line => !line.startsWith(`${missing}=`)).join('\n') + '\n';
  if (crlf) template = template.replace(/\n/g, '\r\n');
  fs.writeFileSync(path.join(dir, '.env.example'), template);
  return dir;
}

function fakeOpenSsl(dir) {
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  const counter = path.join(dir, 'counter');
  fs.writeFileSync(counter, '0');
  fs.writeFileSync(path.join(bin, 'openssl'), `#!/bin/sh\nn=$(cat "$OPENSSL_COUNTER")\nn=$((n+1))\nprintf '%s' "$n" > "$OPENSSL_COUNTER"\nprintf '%064x\\n' "$n"\n`, { mode: 0o755 });
  return { bin, counter };
}

function run(dir, args = [], { withoutOpenSsl = false } = {}) {
  const env = { ...process.env };
  if (withoutOpenSsl) {
    const bin = path.join(dir, 'no-openssl'); fs.mkdirSync(bin);
    for (const command of ['dirname', 'rm', 'tr', 'mv']) {
      const found = spawnSync('/bin/sh', ['-c', `command -v ${command}`], { encoding: 'utf8' }).stdout.trim();
      if (found) fs.symlinkSync(found, path.join(bin, command));
    }
    env.PATH = bin;
  } else {
    const fake = fakeOpenSsl(dir); env.OPENSSL_COUNTER = fake.counter; env.PATH = `${fake.bin}:${env.PATH}`;
  }
  return spawnSync('/bin/sh', [path.join(dir, 'scripts/generer-env.sh'), ...args], { cwd: dir, env, encoding: 'utf8' });
}

function readEnv(dir) { return fs.readFileSync(path.join(dir, '.env'), 'utf8'); }

test('génère dix secrets distincts de 64 caractères et un fichier privé', () => {
  const dir = fixture(); const result = run(dir);
  assert.equal(result.status, 0, result.stderr);
  const content = readEnv(dir);
  const values = secretNames.map(name => content.match(new RegExp(`^${name}=([0-9a-f]{64})$`, 'm'))?.[1]);
  assert.ok(values.every(Boolean)); assert.equal(new Set(values).size, secretNames.length);
  assert.equal(fs.statSync(path.join(dir, '.env')).mode & 0o777, 0o600);
});

test('refuse de remplacer .env sans --force', () => {
  const dir = fixture(); fs.writeFileSync(path.join(dir, '.env'), 'KEEP=1\n');
  const result = run(dir); assert.notEqual(result.status, 0); assert.equal(readEnv(dir), 'KEEP=1\n');
});

test('--force remplace un .env existant', () => {
  const dir = fixture(); fs.writeFileSync(path.join(dir, '.env'), 'KEEP=1\n');
  const result = run(dir, ['--force']); assert.equal(result.status, 0, result.stderr); assert.doesNotMatch(readEnv(dir), /KEEP=1/);
});

test('refuse tout argument inconnu ou surnuméraire', () => {
  for (const args of [['--wrong'], ['--force', 'extra']]) {
    const dir = fixture(); const result = run(dir, args); assert.equal(result.status, 2); assert.match(result.stderr, /Usage:/);
  }
});

test('normalise un template CRLF en LF', () => {
  const dir = fixture({ crlf: true }); const result = run(dir); assert.equal(result.status, 0, result.stderr); assert.doesNotMatch(readEnv(dir), /\r/);
});

test('échoue si une clé obligatoire manque sans publier de .env', () => {
  const dir = fixture({ missing: 'JWT_SECRET' }); const result = run(dir); assert.notEqual(result.status, 0); assert.match(result.stderr, /JWT_SECRET/); assert.equal(fs.existsSync(path.join(dir, '.env')), false);
});

test('échoue clairement si openssl est absent', () => {
  const dir = fixture(); const result = run(dir, [], { withoutOpenSsl: true }); assert.notEqual(result.status, 0); assert.match(result.stderr, /openssl est requis/); assert.equal(fs.existsSync(path.join(dir, '.env')), false);
});
