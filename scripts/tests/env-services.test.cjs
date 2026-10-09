const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('chaque service ne reçoit que ses secrets, sans rotation du fichier source', () => {
  const racine = fs.mkdtempSync(path.join(os.tmpdir(), 'chatvardage-isolation-'));
  try {
    fs.mkdirSync(path.join(racine, 'scripts'));
    const script = path.join(racine, 'scripts/preparer-env-services.sh');
    fs.copyFileSync(path.resolve(__dirname, '../preparer-env-services.sh'), script);
    const source = 'NODE_ENV=production\nJWT_SECRET=jwt-secret\nAUTH_DB_PASSWORD=auth-secret\nMESSAGES_DB_PASSWORD=message-secret\nPOSTGRES_SUPERPASS=super-secret\nREDIS_PASSWORD=redis-secret\nDASHBOARD_SESSION_SECRET=admin-secret\nINTERNAL_SERVICE_TOKEN=internal-secret\nNON_AUTORISE=secret-inattendu\n';
    fs.writeFileSync(path.join(racine, '.env'), source);
    const resultat = spawnSync('sh', [script], { encoding: 'utf8' });
    assert.equal(resultat.status, 0, resultat.stderr);
    const lire = (service) => fs.readFileSync(path.join(racine, '.runtime-env', service, '.env'), 'utf8');
    assert.match(lire('auth'), /JWT_SECRET=jwt-secret/);
    assert.match(lire('auth'), /AUTH_DB_PASSWORD=auth-secret/);
    assert.doesNotMatch(lire('auth'), /super-secret|message-secret|admin-secret/);
    assert.equal(lire('redis'), 'REDIS_PASSWORD=redis-secret\n');
    assert.match(lire('message'), /REDIS_PASSWORD=redis-secret/);
    assert.doesNotMatch(lire('serveur-api'), /jwt-secret|auth-secret|super-secret|admin-secret/);
    assert.doesNotMatch(lire('dashboard'), /internal-secret|jwt-secret|auth-secret/);
    for (const service of ['postgres', 'redis', 'auth', 'room', 'message', 'user-config', 'dashboard', 'serveur-api']) {
      assert.doesNotMatch(lire(service), /NON_AUTORISE/);
    }
    assert.equal(fs.readFileSync(path.join(racine, '.env'), 'utf8'), source);
    assert.equal(fs.statSync(path.join(racine, '.env')).mode & 0o777, 0o600);
    const deuxieme = spawnSync('sh', [script], { encoding: 'utf8' });
    assert.equal(deuxieme.status, 0, deuxieme.stderr);
    assert.equal(lire('auth').includes('JWT_SECRET=jwt-secret'), true);
  } finally {
    fs.rmSync(racine, { recursive: true, force: true });
  }
});
