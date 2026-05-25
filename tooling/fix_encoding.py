#!/usr/bin/env python3
"""
Fix mojibake (double/triple UTF-8 encoded) Romanian characters in Dart source files.

Root cause: Files were saved with Latin-1/Windows-1252 encoding after being read as UTF-8,
causing valid Romanian Unicode chars to appear as garbled multi-char sequences.

This script fixes ALL dart files under lib/ (excluding snapshot directories).
"""

import os
import sys

LIB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib")

# Order matters: fix longer (triple-encoded) patterns BEFORE shorter (double-encoded)
# Triple-encoded: the mojibake string was itself mojibaked again
REPLACEMENTS = [
    # ── Triple-encoded Romanian chars ─────────────────────────────────────────
    # ă triple-encoded: ă→UTF8(C4 83)→CP1252(Äƒ)→UTF8→CP1252 = Ã„Æ'
    ("Ã\u201eÆ\u2018", "ă"),
    # â triple-encoded: â→UTF8(C3 A2)→CP1252(Ã¢)→UTF8→CP1252 = ÃƒÂ¢
    ("ÃƒÂ¢", "â"),
    # î triple-encoded
    ("ÃƒÂ®", "î"),
    # Î triple-encoded
    ("ÃƒÅ½", "Î"),
    # Â triple-encoded (rare)
    ("Ãƒâ€š", "Â"),
    # ș triple-encoded
    ("Ãˆâ„\u00a2", "ș"),
    # Ș triple-encoded
    ("Ãˆ\u02dc", "Ș"),   # Ãˆ + ˜
    # ț triple-encoded
    ("Ãˆâ€º", "ț"),
    # Ț triple-encoded
    ("ÃˆÅ¡", "Ț"),
    # • triple-encoded
    ("Ã¢â‚¬Â¢", "•"),
    # – triple-encoded
    ("Ã¢â‚¬â€"", "–"),
    # " triple-encoded
    ("Ã¢â‚¬Å"", "\u201c"),
    ("Ã¢â‚¬â€\u009d", "\u201d"),

    # ── Double-encoded Romanian lowercase ─────────────────────────────────────
    ("Äƒ", "ă"),   # ă U+0103
    ("Ã¢",  "â"),  # â U+00E2
    ("Ã®",  "î"),  # î U+00EE
    ("È™",  "ș"),  # ș U+0219
    ("È›",  "ț"),  # ț U+021B
    ("Å£",  "ţ"),  # ţ U+0163 (old comma-below)
    ("ÅŸ",  "ş"),  # ş U+015F

    # ── Double-encoded Romanian uppercase ─────────────────────────────────────
    ("Ä‚",  "Ă"),  # Ă U+0102
    ("ÃŽ",  "Î"),  # Î U+00CE
    ("Ã‚",  "Â"),  # Â U+00C2 (rarely used in RO)
    ("Èš",  "Ș"),  # Ș U+0218
    ("Èœ",  "Ț"),  # Ț U+021A
    ("Åž",  "Ş"),  # Ş U+015E

    # ── Smart quotes / typographic chars ──────────────────────────────────────
    ("â€œ",  "\u201c"),  # " left double quote
    ("â€\u009d", "\u201d"),  # " right double quote  (0x9D = Windows-1252 ']' area)
    ("â€˜",  "\u2018"),  # ' left single quote
    ("â€™",  "\u2019"),  # ' right single quote
    ("â€¢",  "•"),        # • bullet U+2022
    ("â€"",  "\u2013"),  # – en-dash U+2013
    ("â€"",  "\u2014"),  # — em-dash U+2014
    ("â€¦",  "\u2026"),  # … ellipsis U+2026
    ("â†'",  "\u2192"),  # → right arrow U+2192
    ("â‚¬",  "\u20ac"),  # € euro U+20AC
]

def fix_file(path: str) -> bool:
    with open(path, "r", encoding="utf-8") as f:
        original = f.read()
    text = original
    for bad, good in REPLACEMENTS:
        text = text.replace(bad, good)
    if text != original:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        return True
    return False

def main():
    if not os.path.isdir(LIB_DIR):
        print(f"ERROR: lib dir not found: {LIB_DIR}")
        sys.exit(1)
    fixed = []
    for root, dirs, files in os.walk(LIB_DIR):
        # Skip snapshot directories
        dirs[:] = [d for d in dirs if "snapshot" not in d.lower()]
        for fname in files:
            if fname.endswith(".dart"):
                fpath = os.path.join(root, fname)
                if fix_file(fpath):
                    rel = os.path.relpath(fpath, LIB_DIR)
                    fixed.append(rel)
                    print(f"  Fixed: {rel}")
    print(f"\nDone. Fixed {len(fixed)} files.")

if __name__ == "__main__":
    main()
