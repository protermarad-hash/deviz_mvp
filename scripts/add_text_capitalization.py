"""
Script pentru adăugarea automată a textCapitalization: TextCapitalization.sentences
în toate câmpurile TextField/TextFormField din proiectul Flutter.

Excluderi:
- Câmpuri cu keyboardType: TextInputType.emailAddress/number/phone/url
- Câmpuri cu obscureText: true
- Câmpuri cu textCapitalization deja setat
- Câmpuri cu labelText/hintText care conțin cuvinte cheie excluse
"""

import os
import re
import shutil
from pathlib import Path

# Cuvinte cheie în labelText/hintText care indică câmpuri excluse
EXCLUDED_LABEL_KEYWORDS = [
    'email', 'e-mail', 'parola', 'parolă', 'password',
    'cui', 'cif', 'iban', 'tva', 'url', 'www', 'http',
    'numar de inregistrare', 'cod postal', 'cod fiscal',
    'registrul comertului', 'reg. com', 'j/',
    'nr. factura', 'numar factura', 'nr factura',
]

# KeyboardType-uri excluse
EXCLUDED_KEYBOARD_TYPES = [
    'TextInputType.emailAddress',
    'TextInputType.number',
    'TextInputType.phone',
    'TextInputType.url',
    'TextInputType.visiblePassword',
]

# Fișiere de procesat
LIB_PATH = Path(r'C:\Users\Lenovo\develop\deviz_mvp\lib')

def extract_field_block(content, start_pos):
    """Extrage blocul unui TextField/TextFormField pornind de la poziția dată."""
    depth = 0
    i = start_pos
    while i < len(content):
        if content[i] == '(':
            depth += 1
        elif content[i] == ')':
            depth -= 1
            if depth == 0:
                return content[start_pos:i+1]
        i += 1
    return content[start_pos:]

def should_exclude_block(block):
    """Verifică dacă un bloc de TextField trebuie exclus."""
    block_lower = block.lower()

    # Verifică dacă are deja textCapitalization
    if 'textcapitalization:' in block_lower:
        return True

    # Verifică keyboardType exclus
    for kt in EXCLUDED_KEYBOARD_TYPES:
        if kt.lower() in block_lower:
            return True

    # Verifică obscureText
    if 'obscuretext: true' in block_lower:
        return True

    # Verifică cuvinte cheie excluse în labelText sau hintText
    # Caută valoarea labelText și hintText
    label_match = re.search(r"label(?:Text)?\s*:\s*['\"]([^'\"]+)['\"]", block, re.IGNORECASE)
    hint_match = re.search(r"hint(?:Text)?\s*:\s*['\"]([^'\"]+)['\"]", block, re.IGNORECASE)

    label = (label_match.group(1) if label_match else '').lower()
    hint = (hint_match.group(1) if hint_match else '').lower()
    combined = label + ' ' + hint

    for keyword in EXCLUDED_LABEL_KEYWORDS:
        if keyword in combined:
            return True

    # Verifică pattern-uri numerice în label (conțin doar cifre sau %/€/$)
    if label and re.match(r'^[\d\s%€$.,/]+$', label):
        return True

    return False

def add_capitalization_to_file(filepath):
    """Adaugă textCapitalization în câmpurile potrivite dintr-un fișier."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Caută TextField( și TextFormField(
    pattern = re.compile(r'(?<!\w)(TextField|TextFormField)\s*\(')

    modifications = []
    for match in pattern.finditer(content):
        widget_name = match.group(1)
        block_start = match.start() + len(widget_name)
        # block_start este pe '('
        block = extract_field_block(content, block_start)

        if should_exclude_block(block):
            continue

        # Găsește pozitia după '(' pentru a insera textCapitalization
        insert_pos = block_start + 1  # după '('

        # Verifică dacă există whitespace/newline după '('
        # Găsim primul caracter non-space după '('
        local_pos = 1  # în cadrul block-ului
        while local_pos < len(block) and block[local_pos] in ' \t':
            local_pos += 1

        modifications.append((block_start + 1, widget_name, block))

    if not modifications:
        return 0

    # Aplică modificările de la sfârșit spre început pentru a nu invalida pozițiile
    new_content = content
    count = 0

    for insert_pos, widget_name, block in reversed(modifications):
        # Determină indentarea liniei curente
        # Găsim începutul liniei care conține TextField/TextFormField
        line_start = new_content.rfind('\n', 0, insert_pos - len(widget_name))
        if line_start == -1:
            line_start = 0
        else:
            line_start += 1

        line_content = new_content[line_start:insert_pos - len(widget_name)]
        indent = len(line_content) - len(line_content.lstrip())
        base_indent = ' ' * indent
        prop_indent = base_indent + '  '

        # Verifică dacă blocul are proprietăți pe linii separate sau pe aceeași linie
        block_after_paren = block[1:].lstrip()

        if '\n' in block_after_paren[:50]:
            # Bloc multi-linie: inserăm pe linie nouă după '('
            insertion = f'\n{prop_indent}textCapitalization: TextCapitalization.sentences,'
            new_content = new_content[:insert_pos] + insertion + new_content[insert_pos:]
        else:
            # Bloc single-linie: inserăm înainte de prima proprietate
            insertion = f'textCapitalization: TextCapitalization.sentences, '
            new_content = new_content[:insert_pos] + insertion + new_content[insert_pos:]

        count += 1

    if count > 0:
        # Backup
        backup_path = str(filepath) + '.cap_bak'
        if not os.path.exists(backup_path):
            shutil.copy2(filepath, backup_path)

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)

    return count

def process_all_files():
    """Procesează toate fișierele .dart din lib/features/."""
    features_path = LIB_PATH / 'features'
    app_path = LIB_PATH / 'app'

    total_files = 0
    total_fields = 0
    results = []

    search_paths = [features_path, app_path]

    for search_path in search_paths:
        for dart_file in search_path.rglob('*.dart'):
            # Skip backup files
            if dart_file.suffix in ['.bak', '.bak2', '.cap_bak'] or '.bak' in dart_file.name:
                continue
            # Skip test files
            if 'test' in str(dart_file).lower():
                continue

            count = add_capitalization_to_file(dart_file)
            if count > 0:
                total_files += 1
                total_fields += count
                rel_path = dart_file.relative_to(LIB_PATH)
                results.append(f"  {rel_path}: +{count} câmpuri")

    import sys
    out = sys.stdout
    print(f"\n=== REZULTAT ===")
    print(f"Fisiere modificate: {total_files}")
    print(f"Campuri actualizate: {total_fields}")
    print(f"\nDetalii:")
    for r in sorted(results):
        try:
            print(r)
        except UnicodeEncodeError:
            print(r.encode('ascii', 'replace').decode('ascii'))

if __name__ == '__main__':
    process_all_files()
