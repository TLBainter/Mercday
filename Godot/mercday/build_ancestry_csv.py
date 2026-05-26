"""
Rebuild Ancestries.csv with proper CSV quoting for all multi-value cells.
"""
import io

TYPE_KEYWORDS = {'Hominid', 'Elemental', 'Beast', 'Fey', 'Daemon', 'Assembly', 'Plant', 'Undead', 'Ethereal'}
KNOWLEDGE_KEYWORDS = {
    'Agriculture', 'Architecture', 'Forestry', 'Hunting', 'Dueling', 'Tactics', 'Dancing', 'Music',
    'Dramaturgy', 'Comedy', 'Culinary', 'Reconnaissance', 'Zoology', 'Cryptozoology', 'Mythozoology',
    'Biology', 'Botany', 'Engineering', 'Geology', 'Forensics', 'Medicine', 'Meteorology', 'Oceanography',
    'Psychology', 'Technology', 'Toxicology', 'Diplomacy', 'Finance', 'Law', 'Salesmanship', 'Education',
    'History', 'Linguistics', 'Logistics', 'Philosophy', 'Theology', 'Chivalry', 'Colosseum', 'High Society',
    'Lowborn', 'Pre-Reckoning', 'Primeval', 'Nautical', 'Travel', 'Aerial', 'Domain Walking', 'Immortal',
    'Ethereal', 'Undead', 'Spectral', 'First Aid', 'Mechanology', 'Suorr', 'Aerdis', 'Buern', 'Cyfrolaef',
    'Fainarr', 'Gloria', 'Hel', 'Kathaya', 'Mire', 'Rossade', 'Vaernebo', 'Zukei', 'Miliim', 'Copari',
    'Aldurstein', 'Umbra', 'Cavern', 'Desert', 'Forest', 'Marsh', 'Mountain', 'Plain', 'Sea', 'Sky',
    'Snowy', 'Tropical', 'Volcanic', 'Undercity', 'Uppercity', 'Cosmos', 'Unknowables', 'Assembly', 'Weird',
    'Fey', 'Daemon', 'Disruptomancy', 'Necromancy', 'Hemomancy', 'Osteomancy', 'Astromancy', 'Aeromancy',
    'Hydromancy', 'Pyromancy', 'Geomancy', 'Creomancy', 'Illustromancy', 'Oneiromancy', 'Phonomancy',
    'Spatiomancy', 'Tasseomancy', 'Theomancy', 'Magic',
}
RARITIES = {'Common', 'Uncommon', 'Rare', 'Legendary', 'Very Rare'}
# Tools that don't end in "'s" need to be listed explicitly
NON_APOSTROPHE_TOOLS = {'Mount Tack'}
DRAWBACK_TERMS = {
    'Fragile Body', 'Lightweight', 'Photosensitive', 'Heat Averse', 'Cold Averse',
    'Crush Averse', 'Poison Averse', 'Unusual Look', 'Peaceable', 'Exposed',
    'Dragonfly Wings', 'Unwalkable', 'Shallowborn',
}


def is_tool(s):
    return s.endswith("'s") or s in NON_APOSTROPHE_TOOLS


def is_circ(s):
    return '(' in s and ')' in s


def is_knowledge(s):
    if s == '':
        return False
    if 'mancy' in s.lower():
        return True
    return s in KNOWLEDGE_KEYWORDS


def split_perks_drawbacks(tokens):
    """Split combined perk+drawback tokens using DRAWBACK_TERMS."""
    perks = []
    drawbacks = []
    in_drawbacks = False
    for t in tokens:
        if t in DRAWBACK_TERMS:
            in_drawbacks = True
        if in_drawbacks:
            drawbacks.append(t)
        else:
            perks.append(t)
    return ', '.join(perks), ', '.join(drawbacks)


def parse_after_size(after_size):
    """Parse types(9), hybrid(10), knowledge(11), tool(12), circ(13), stat(14) from tokens."""
    i = 0
    # Skip leading empties (col8-size and possibly col9-types empties)
    while i < len(after_size) and after_size[i] == '':
        i += 1
    # Collect TYPE_KEYWORD tokens as types
    type_start = i
    while i < len(after_size) and after_size[i] in TYPE_KEYWORDS:
        i += 1
    types = ', '.join(after_size[type_start:i])
    # Skip empties after types (hybrid empty)
    while i < len(after_size) and after_size[i] == '':
        i += 1
    # Collect non-knowledge, non-tool, non-circ tokens as hybrid
    hybrid_start = i
    while i < len(after_size) and not is_knowledge(after_size[i]) and not is_tool(after_size[i]) and not is_circ(after_size[i]):
        i += 1
    hybrid = ', '.join(t for t in after_size[hybrid_start:i] if t)
    # Rest: knowledge+tool+circ+stat from end backwards
    remaining = after_size[i:]
    end_i = len(remaining) - 1
    while end_i >= 0 and remaining[end_i] == '':
        end_i -= 1
    stat_tokens = []
    while end_i >= 0 and not is_tool(remaining[end_i]) and not is_circ(remaining[end_i]):
        stat_tokens.insert(0, remaining[end_i])
        end_i -= 1
    circ_tokens = []
    while end_i >= 0 and is_circ(remaining[end_i]):
        circ_tokens.insert(0, remaining[end_i])
        end_i -= 1
    tool_tokens = []
    while end_i >= 0 and is_tool(remaining[end_i]):
        tool_tokens.insert(0, remaining[end_i])
        end_i -= 1
    knowledge = ', '.join(remaining[:end_i+1])
    return types, hybrid, knowledge, ', '.join(tool_tokens), ', '.join(circ_tokens), ', '.join(stat_tokens)


def csv_quote(value):
    """Quote a CSV field if necessary."""
    if ',' in value or '"' in value or '\n' in value:
        return '"' + value.replace('"', '""') + '"'
    return value


def row_to_csv(fields):
    return ','.join(csv_quote(f) for f in fields)


def reconstruct_row(parts):
    """Reconstruct a row into correct 22-column CSV structure."""
    parts = [p.strip() for p in parts]
    name = parts[0]
    if not name:
        return None  # separator row

    # Find rarity
    rarity_pos = -1
    for i in range(1, len(parts)):
        if parts[i] in RARITIES:
            rarity_pos = i
            break
    if rarity_pos < 0:
        print(f"  WARNING: No rarity for {name}")
        return None

    col1_bloodlines = ', '.join(p for p in parts[1:rarity_pos])
    col2_rarity = parts[rarity_pos]
    is_bloodline = (col1_bloodlines == '')
    remaining = parts[rarity_pos+1:]

    if not is_bloodline:
        # ANCESTRY ROW: find life_exp (first numeric or N/A)
        life_pos = -1
        for i, v in enumerate(remaining):
            if v == 'N/A' or (v != '' and v.lstrip('-').isdigit()):
                life_pos = i
                break
        if life_pos < 0:
            print(f"  WARNING: No life_exp for {name}")
            return None

        perk_draw = remaining[:life_pos]
        col5_life = remaining[life_pos] if life_pos < len(remaining) else ''
        col6_dex = remaining[life_pos+1] if life_pos+1 < len(remaining) else ''
        col7_vig = remaining[life_pos+2] if life_pos+2 < len(remaining) else ''
        col8_size = remaining[life_pos+3] if life_pos+3 < len(remaining) else ''
        after_size_raw = remaining[life_pos+4:]
    else:
        # BLOODLINE ROW: find 4 consecutive empties
        col5_life = col6_dex = col7_vig = col8_size = ''
        consec = -1
        for i in range(len(remaining)):
            if all(k < len(remaining) and remaining[k] == '' for k in range(i, i+4)):
                consec = i
                break
        if consec >= 0:
            perk_draw = remaining[:consec]
            after_size_raw = remaining[consec+4:]
        else:
            perk_draw = []
            after_size_raw = remaining

    # Split perk_draw into perks and drawbacks
    sep_pos = next((i for i, t in enumerate(perk_draw) if t == ''), -1)
    if sep_pos >= 0:
        col3_perks = ', '.join(t for t in perk_draw[:sep_pos] if t)
        col4_drawbacks = ', '.join(t for t in perk_draw[sep_pos+1:] if t)
    else:
        perk_draw_nonempty = [t for t in perk_draw if t]
        col3_perks, col4_drawbacks = split_perks_drawbacks(perk_draw_nonempty)

    # Remove trailing empties from after_size
    e = len(after_size_raw)
    while e > 0 and after_size_raw[e-1] == '':
        e -= 1
    after_size = after_size_raw[:e]

    col9_types, col10_hybrid, col11_knowledge, col12_tool, col13_circ, col14_stat = parse_after_size(after_size)

    result = [
        name, col1_bloodlines, col2_rarity, col3_perks, col4_drawbacks,
        col5_life, col6_dex, col7_vig, col8_size,
        col9_types, col10_hybrid,
        col11_knowledge, col12_tool, col13_circ, col14_stat,
        '', '', '', '', '', '', ''  # 7 [Ignore] columns
    ]
    return result


# Read and process the file
with open(r'u:\Game Design\MyProjects\MercManager\Godot\mercday\CSVs\Ancestries.csv', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines()
output_lines = []
output_lines.append(lines[0])  # Header unchanged

errors = []
for line_idx, line in enumerate(lines[1:], 2):
    parts = line.split(',')
    name = parts[0].strip()

    if not name:
        output_lines.append('')  # Separator row
        continue

    result = reconstruct_row(parts)
    if result is None:
        errors.append(f"Line {line_idx}: Failed to reconstruct {name}")
        output_lines.append(line)  # Keep original on failure
        continue

    if len(result) != 22:
        errors.append(f"Line {line_idx}: {name} got {len(result)} cols, expected 22")

    output_lines.append(row_to_csv(result))

# Verify key rows
print("=== Key row verification ===")
for out_line in output_lines:
    for check in ['Steeljoint', 'Daemonborn', 'Dracipava', 'Moet', 'Dryad', 'Angelic', 'Toadstool', 'Arcane,']:
        if out_line.startswith(check.rstrip(',')):
            print(f"\n{check}: {out_line[:200]}")
            break

if errors:
    print("\n=== ERRORS ===")
    for e in errors:
        print(e)
else:
    print("\n=== No errors ===")

# Write output
out_path = r'u:\Game Design\MyProjects\MercManager\Godot\mercday\CSVs\Ancestries.csv'
with open(out_path, 'w', encoding='utf-8', newline='') as f:
    f.write('\n'.join(output_lines))
    if not output_lines[-1].endswith('\n'):
        pass  # no trailing newline needed

print(f"\nWrote {len(output_lines)} lines to {out_path}")
