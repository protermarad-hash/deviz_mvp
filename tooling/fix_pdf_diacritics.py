# fix_pdf_diacritics.py - Fix missing Romanian diacritics in PDF service files
# Runs in-place replacement on all *pdf*service*.dart files plus lib/core/pdf_service.dart
import os, glob

ROOT = os.path.join(os.path.dirname(__file__), '..', 'lib')
ROOT = os.path.normpath(ROOT)

# Replacements: (bad, good) - ORDER MATTERS - longer/more specific first
REPLACEMENTS = [
    # Long sentences first
    (
        'beneficiarul si/sau destinatarul comercial confirma primirea devizului / ofertei si isi exprima acordul pentru efectuarea interventiei in conditiile comerciale mentionate in document.',
        'beneficiarul \u0219i/sau destinatarul comercial confirm\u0103 primirea devizului / ofertei \u0219i \u00ee\u0219i exprim\u0103 acordul pentru efectuarea interven\u021biei \u00een condi\u021biile comerciale men\u021bionate \u00een document.'
    ),
    (
        'Nu exista pozitii pentru aceasta sectiune.',
        'Nu exist\u0103 pozi\u021bii pentru aceast\u0103 sec\u021biune.'
    ),
    (
        'Oferta include o structura interna de cost cu regie si profit calculate procentual.',
        'Oferta include o structur\u0103 intern\u0103 de cost cu regie \u0219i profit calculate procentual.'
    ),
    # Compound phrases (before simpler ones)
    ('OFERTA COMERCIALA', 'OFERT\u0102 COMERCIAL\u0102'),
    ('DEVIZ / OFERTA', 'DEVIZ / OFERT\u0102'),
    ('Sinteza comerciala', 'Sintez\u0103 comercial\u0103'),
    ('Conditie comerciala', 'Condi\u021bie comercial\u0103'),
    ('Observatii / Registratura', 'Observa\u021bii / Registratur\u0103'),
    ('Observatii tehnice', 'Observa\u021bii tehnice'),
    ('Observatii de executie', 'Observa\u021bii de execu\u021bie'),
    ('Observatii juridice', 'Observa\u021bii juridice'),
    ('Observatii acceptare', 'Observa\u021bii acceptare'),
    ('Stare/Observatii', 'Stare/Observa\u021bii'),
    ('Observatii:', 'Observa\u021bii:'),
    ('Observatii', 'Observa\u021bii'),
    ('Referinta Registratura', 'Referin\u021b\u0103 Registratur\u0103'),
    ('Registratura', 'Registratur\u0103'),
    ('Semnaturi', 'Semn\u0103turi'),
    # Semnatura variants - specific first, generic last
    ('Semnatura neaplicata', 'Semn\u0103tur\u0103 neaplicat\u0103'),
    ('Semnatura angajatului', 'Semn\u0103tura angajatului'),
    ('Semnatura client / beneficiar', 'Semn\u0103tur\u0103 client / beneficiar'),
    ('Semnatura emitent / reprezentant firma', 'Semn\u0103tur\u0103 emitent / reprezentant firm\u0103'),
    ('Semnatura client', 'Semn\u0103tur\u0103 client'),
    ('Semnatura tehnician', 'Semn\u0103tur\u0103 tehnician'),
    ('Semnatura beneficiar', 'Semn\u0103tur\u0103 beneficiar'),
    ('Semnatura / validare', 'Semn\u0103tur\u0103 / validare'),
    ('Semnatura: __________________________', 'Semn\u0103tur\u0103: __________________________'),
    ('Semnatura', 'Semn\u0103tur\u0103'),
]

def fix_file(fpath):
    with open(fpath, encoding='utf-8') as f:
        original = f.read()
    text = original
    for bad, good in REPLACEMENTS:
        text = text.replace(bad, good)
    if text != original:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(text)
        return True
    return False

pdf_files = glob.glob(os.path.join(ROOT, '**', '*pdf*service*.dart'), recursive=True)
pdf_files.append(os.path.join(ROOT, 'core', 'pdf_service.dart'))
seen = set()
fixed = []
for fpath in pdf_files:
    norm = os.path.normpath(fpath)
    if norm in seen:
        continue
    seen.add(norm)
    if os.path.exists(norm) and fix_file(norm):
        fixed.append(norm.replace(ROOT + os.sep, ''))

print(f'Fixed {len(fixed)} files:')
for f in fixed:
    print(f'  {f}')
print('Done.')
