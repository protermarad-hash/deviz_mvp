#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// scripts/publish_release.js
// Publicare automată ProVentaris: upload APK + ZIP în Firebase Storage
// + actualizare Firestore app_config/version_info
//
// Utilizare:
//   node scripts/publish_release.js --version 1.1.0 --build 4 --notes "Fix salarizare"
//
// Opțional (dacă vrei doar Android sau doar Windows):
//   node scripts/publish_release.js --version 1.1.0 --build 4 --apk-only
//   node scripts/publish_release.js --version 1.1.0 --build 4 --windows-only
//
// Cerințe: firebase login deja efectuat (token stocat local automat)
// ─────────────────────────────────────────────────────────────────────────────

'use strict';

const fs   = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');

// ── Configurare proiect ───────────────────────────────────────────────────────
const PROJECT_ID     = 'devizpro-ultra-pilot';
const BUCKET         = 'devizpro-ultra-pilot.firebasestorage.app';
// OAuth client folosit de Firebase CLI (din firebase-tools/lib/api.js)
const FB_CLIENT_ID   = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FB_CLIENT_SEC  = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const CONFIG_PATH    = path.join(
  process.env.USERPROFILE || process.env.HOME,
  '.config', 'configstore', 'firebase-tools.json'
);

// ── Argumente CLI ─────────────────────────────────────────────────────────────
function parseArgs() {
  const raw  = process.argv.slice(2);
  const args = {};
  for (let i = 0; i < raw.length; i++) {
    if (raw[i].startsWith('--')) {
      const key = raw[i].slice(2);
      args[key] = (i + 1 < raw.length && !raw[i + 1].startsWith('--'))
        ? raw[++i]
        : true;
    }
  }
  return args;
}

// ── OAuth: citire + refresh token ────────────────────────────────────────────
async function getAccessToken() {
  if (!fs.existsSync(CONFIG_PATH)) {
    throw new Error(
      `Firebase config lipsă: ${CONFIG_PATH}\n` +
      `Rulează 'firebase login' o dată și reîncearcă.`
    );
  }

  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  const tokens = config.tokens;
  if (!tokens?.refresh_token) {
    throw new Error('Nu există refresh_token. Rulează "firebase login" din nou.');
  }

  // Dacă access_token-ul expiră în mai puțin de 2 minute, îl reîmprospătăm
  if (tokens.expires_at && tokens.expires_at > Date.now() + 120_000) {
    return tokens.access_token;
  }

  console.log('[auth] Token expirat — reîmprospătare...');
  const body = new URLSearchParams({
    client_id:     FB_CLIENT_ID,
    client_secret: FB_CLIENT_SEC,
    grant_type:    'refresh_token',
    refresh_token: tokens.refresh_token,
  });

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    body.toString(),
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Token refresh eșuat (${resp.status}): ${txt}`);
  }

  const data = await resp.json();
  tokens.access_token = data.access_token;
  tokens.expires_at   = Date.now() + data.expires_in * 1000;
  if (data.refresh_token) tokens.refresh_token = data.refresh_token;
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  console.log('[auth] ✓ Token reîmprospătat și salvat');
  return data.access_token;
}

// ── Upload fișier în Firebase Storage (resumable upload) ─────────────────────
async function uploadFile(token, localPath, storagePath) {
  const stats    = fs.statSync(localPath);
  const sizeMb   = (stats.size / 1024 / 1024).toFixed(1);
  const fileName = path.basename(localPath);

  console.log(`[upload] ${fileName} (${sizeMb} MB) → gs://${BUCKET}/${storagePath}`);

  // Pas 1: inițializează resumable upload
  const initUrl = `https://storage.googleapis.com/upload/storage/v1/b/` +
    `${encodeURIComponent(BUCKET)}/o?uploadType=resumable&name=${encodeURIComponent(storagePath)}`;

  const initResp = await fetch(initUrl, {
    method:  'POST',
    headers: {
      'Authorization':           `Bearer ${token}`,
      'Content-Type':            'application/json',
      'X-Upload-Content-Type':   'application/octet-stream',
      'X-Upload-Content-Length': stats.size.toString(),
    },
    body: JSON.stringify({ name: storagePath }),
  });

  if (!initResp.ok) {
    const txt = await initResp.text();
    throw new Error(`Upload init eșuat (${initResp.status}): ${txt}`);
  }

  const uploadUrl = initResp.headers.get('location');
  if (!uploadUrl) throw new Error('Location header lipsă în răspunsul de init upload');

  // Pas 2: trimite conținutul fișierului
  const fileData = fs.readFileSync(localPath);
  const uploadResp = await fetch(uploadUrl, {
    method:  'PUT',
    headers: {
      'Content-Type':   'application/octet-stream',
      'Content-Length': stats.size.toString(),
    },
    body: fileData,
  });

  if (!uploadResp.ok) {
    const txt = await uploadResp.text();
    throw new Error(`Upload conținut eșuat (${uploadResp.status}): ${txt}`);
  }

  const meta = await uploadResp.json();
  console.log(`[upload] ✓ ${fileName} uploadat (${sizeMb} MB)`);
  return meta;
}

// ── Obține/creează download URL cu token Firebase ────────────────────────────
// Firebase Storage API (firebasestorage.googleapis.com) nu permite setarea
// firebaseStorageDownloadTokens via PATCH. Folosim GCS JSON API
// (storage.googleapis.com) care permite actualizarea custom metadata direct.
async function getDownloadUrl(token, storagePath) {
  // GCS JSON API — citire metadata obiect
  const gcsMetaUrl = `https://storage.googleapis.com/storage/v1/b/` +
    `${encodeURIComponent(BUCKET)}/o/${encodeURIComponent(storagePath)}`;

  const metaResp = await fetch(gcsMetaUrl, {
    headers: { 'Authorization': `Bearer ${token}` },
  });
  if (!metaResp.ok) {
    const txt = await metaResp.text();
    throw new Error(`Citire metadata GCS eșuată (${metaResp.status}): ${txt}`);
  }

  const meta = await metaResp.json();
  let dlToken = meta.metadata?.firebaseStorageDownloadTokens;

  if (!dlToken) {
    // GCS JSON API — setare custom metadata (suportă firebaseStorageDownloadTokens)
    dlToken = randomUUID();
    const patchResp = await fetch(gcsMetaUrl, {
      method:  'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({
        metadata: { firebaseStorageDownloadTokens: dlToken },
      }),
    });
    if (!patchResp.ok) {
      const txt = await patchResp.text();
      throw new Error(`Setare token GCS eșuată (${patchResp.status}): ${txt}`);
    }
    console.log(`[url] ✓ Token download creat pentru ${path.basename(storagePath)}`);
  } else {
    console.log(`[url] ✓ Token download existent pentru ${path.basename(storagePath)}`);
  }

  return `https://firebasestorage.googleapis.com/v0/b/` +
    `${encodeURIComponent(BUCKET)}/o/${encodeURIComponent(storagePath)}` +
    `?alt=media&token=${dlToken}`;
}

// ── Actualizare Firestore app_config/version_info ────────────────────────────
async function updateFirestore(token, { version, buildNumber, apkUrl, windowsUrl, notes }) {
  const docPath = `projects/${PROJECT_ID}/databases/(default)/documents/app_config/version_info`;

  // Construim lista câmpurilor de actualizat (updateMask)
  const fields     = {};
  const maskFields = [];

  function addField(key, value) {
    fields[key] = value;
    maskFields.push(key);
  }

  addField('latestVersion',     { stringValue: version });
  addField('latestBuildNumber', { integerValue: buildNumber.toString() });
  addField('releaseNotes',      { stringValue: notes });
  addField('forceUpdate',       { booleanValue: false });
  if (apkUrl)     addField('apkUrl',        { stringValue: apkUrl });
  if (windowsUrl) addField('windowsExeUrl', { stringValue: windowsUrl });

  const mask    = maskFields.map(f => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const url     = `https://firestore.googleapis.com/v1/${docPath}?${mask}`;

  const resp = await fetch(url, {
    method:  'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({ fields }),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Firestore update eșuat (${resp.status}): ${txt}`);
  }

  console.log('[firestore] ✓ app_config/version_info actualizat');
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const args = parseArgs();

  const version     = args.version || args.v;
  const buildNumber = parseInt(args.build || args.b || '0', 10);
  const notes       = (typeof args.notes === 'string') ? args.notes : '';
  const apkOnly     = !!args['apk-only'];
  const windowsOnly = !!args['windows-only'];

  if (!version || !buildNumber) {
    console.error(
      'Utilizare: node scripts/publish_release.js --version 1.1.0 --build 4 --notes "Descriere"\n' +
      'Opțional:  --apk-only | --windows-only'
    );
    process.exit(1);
  }

  const apkPath = path.join('build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
  const zipPath = path.join('build', `proventaris-windows-v${version}-build${buildNumber}.zip`);

  const doApk     = !windowsOnly && fs.existsSync(apkPath);
  const doWindows = !apkOnly     && fs.existsSync(zipPath);

  console.log(`\n🚀  Publicare ProVentaris v${version}+${buildNumber}`);
  console.log(`    Note release: ${notes || '(fără)'}`);
  console.log(`    APK Android:  ${doApk     ? '✓ ' + apkPath  : '✗ lipsă (se sare)'}`);
  console.log(`    ZIP Windows:  ${doWindows ? '✓ ' + zipPath  : '✗ lipsă (se sare)'}\n`);

  if (!doApk && !doWindows) {
    console.error('Niciunul dintre fișiere nu există. Rulează flutter build mai întâi.');
    process.exit(1);
  }

  // Token OAuth
  console.log('[auth] Citire token Firebase CLI...');
  const token = await getAccessToken();
  console.log('[auth] ✓ Token valid\n');

  let apkUrl     = '';
  let windowsUrl = '';

  // Upload APK
  if (doApk) {
    const storagePath = `app_releases/android/proventaris-v${version}-build${buildNumber}.apk`;
    await uploadFile(token, apkPath, storagePath);
    apkUrl = await getDownloadUrl(token, storagePath);
  }

  // Upload ZIP Windows
  if (doWindows) {
    const storagePath = `app_releases/windows/proventaris-windows-v${version}-build${buildNumber}.zip`;
    await uploadFile(token, zipPath, storagePath);
    windowsUrl = await getDownloadUrl(token, storagePath);
  }

  // Actualizare Firestore
  console.log('\n[firestore] Actualizare app_config/version_info...');
  await updateFirestore(token, { version, buildNumber, apkUrl, windowsUrl, notes });

  // Raport final
  console.log('\n✅  Publicare completă!');
  console.log(`    Versiune: v${version}+${buildNumber}`);
  if (apkUrl)     console.log(`    APK URL:  ${apkUrl}`);
  if (windowsUrl) console.log(`    WIN URL:  ${windowsUrl}`);
  console.log('\n    Aplicația detectează update-ul la următoarea pornire.');
}

main().catch(err => {
  console.error('\n❌  Eroare:', err.message);
  process.exit(1);
});
