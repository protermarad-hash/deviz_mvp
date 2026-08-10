#!/usr/bin/env node
// PreToolUse hook — blocheaza Read/Bash/Write/Edit/PowerShell pe fisiere de credentiale cunoscute.
// Vezi CLAUDE.md, sectiunea "REGULI DE SECURITATE - CREDENTIALE" (precedent 10 aug. 2026).
// Extins 10 aug. 2026: gap descoperit — Write si PowerShell (tool dedicat) nu erau acoperite
// de matcher-ul initial "Read|Bash", desi block-credentials.js le suporta deja structural
// (verifica tool_input.file_path / .command / .path, prezente si la Write/Edit/PowerShell).

const BLOCKED_PATTERNS = [
  'configstore',
  'firebase-tools.json',
  'serviceAccount',
  '.firebaserc',
  '.env',
];

let data = '';
process.stdin.on('data', (chunk) => {
  data += chunk;
});

process.stdin.on('end', () => {
  try {
    const input = JSON.parse(data);
    const toolInput = input.tool_input || {};
    const target = [
      toolInput.file_path,
      toolInput.command,
      toolInput.path,
    ]
      .filter(Boolean)
      .join(' ');

    const hit = BLOCKED_PATTERNS.find((p) => target.includes(p));
    if (hit) {
      process.stderr.write(
        `BLOCAT de hook de securitate: tinta contine "${hit}" - pare a fi un fisier de credentiale.\n` +
          'Agentul NU are voie sa citeasca/copieze/reutilizeze fisiere de credentiale in afara ' +
          'scopului intern al tool-ului MCP/scriptului sanctionat care le foloseste deja.\n' +
          'Opreste-te si raporteaza aceasta limitare utilizatorului - NU improviza acces alternativ.\n' +
          'Vezi CLAUDE.md, sectiunea "REGULI DE SECURITATE - CREDENTIALE".\n'
      );
      process.exit(2);
    }
    process.exit(0);
  } catch (e) {
    // Input neasteptat/nevalid - nu bloca, doar lasa tool-ul sa continue.
    process.exit(0);
  }
});
