"""
Analyze Ancestries.csv structure to find hybrid_options and understand column layout.
"""

with open(r'u:\Game Design\MyProjects\MercManager\Godot\mercday\CSVs\Ancestries.csv', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines()

RARITIES = {'Common', 'Uncommon', 'Rare', 'Legendary', 'Very Rare'}
TYPE_KEYWORDS = {'Hominid', 'Elemental', 'Beast', 'Fey', 'Daemon', 'Assembly', 'Plant', 'Undead', 'Ethereal'}

print("=== All rows - after_stats structure (first 10 tokens) ===")
for line_idx, line in enumerate(lines[1:], 2):
    parts = [p.strip() for p in line.split(',')]
    name = parts[0]
    if not name:
        continue
    rarity_pos = -1
    for i in range(1, len(parts)):
        if parts[i] in RARITIES:
            rarity_pos = i
            break
    if rarity_pos < 0:
        continue

    is_bloodline = (parts[1].strip() == '')
    remaining = parts[rarity_pos+1:]

    if not is_bloodline:
        # Ancestry: find life_exp
        life_pos = -1
        for i, v in enumerate(remaining):
            if v == 'N/A' or (v != '' and v.lstrip('-').isdigit()):
                life_pos = i
                break
        if life_pos < 0:
            continue
        after_size = remaining[life_pos+4:]
        label = 'ANCESTRY'
    else:
        # Bloodline: find 4 consecutive empties
        consec = -1
        for i in range(len(remaining)):
            if all(j < len(remaining) and remaining[j] == '' for j in range(i, i+4)):
                consec = i
                break
        after_size = remaining[consec+4:] if consec >= 0 else remaining
        label = 'bloodline'

    # Types
    i = 0
    types = []
    while i < len(after_size) and after_size[i] in TYPE_KEYWORDS:
        types.append(after_size[i])
        i += 1

    # What comes after types (should be hybrid + knowledge start)
    next_tokens = after_size[i:i+6]
    print(f"  L{line_idx} {name} [{label}]: types={types!r}, next={next_tokens!r}")
