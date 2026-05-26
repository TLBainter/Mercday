"""
Fix Ancestries.csv and Locations.csv by properly quoting multi-value cells.
"""
import csv
import io
import re

RARITIES = {'Common', 'Uncommon', 'Rare', 'Legendary', 'Very Rare'}

TYPE_KEYWORDS = {
    'Hominid', 'Elemental', 'Beast', 'Fey', 'Daemon', 'Assembly',
    'Plant', 'Undead', 'Ethereal'
}

KNOWLEDGE_KEYWORDS = {
    'Agriculture', 'Architecture', 'Forestry', 'Hunting', 'Dueling',
    'Tactics', 'Dancing', 'Music', 'Dramaturgy', 'Comedy', 'Culinary',
    'Reconnaissance', 'Zoology', 'Cryptozoology', 'Mythozoology',
    'Biology', 'Botany', 'Engineering', 'Geology', 'Forensics',
    'Medicine', 'Meteorology', 'Oceanography', 'Psychology', 'Technology',
    'Toxicology', 'Diplomacy', 'Finance', 'Law', 'Salesmanship', 'Education',
    'History', 'Linguistics', 'Logistics', 'Philosophy', 'Theology',
    'Chivalry', 'Colosseum', 'High Society', 'Lowborn', 'Pre-Reckoning',
    'Primeval', 'Nautical', 'Travel', 'Aerial', 'Domain Walking',
    'Immortal', 'Ethereal', 'Undead', 'Spectral',
    'First Aid', 'Mechanology', 'Suorr', 'Aerdis', 'Buern', 'Cyfrolaef',
    'Fainarr', 'Gloria', 'Hel', 'Kathaya', 'Mire', 'Rossade', 'Vaernebo',
    'Zukei', 'Miliim', 'Copari', 'Aldurstein',
    'Umbra', 'Cavern', 'Desert', 'Forest', 'Marsh', 'Mountain', 'Plain',
    'Sea', 'Sky', 'Snowy', 'Tropical', 'Volcanic', 'Undercity', 'Uppercity',
    'Cosmos', 'Unknowables', 'Assembly', 'Weird', 'Fey', 'Daemon',
    'Disruptomancy', 'Necromancy', 'Hemomancy', 'Osteomancy',
    'Astromancy', 'Aeromancy', 'Hydromancy', 'Pyromancy', 'Geomancy',
    'Creomancy', 'Illustromancy', 'Oneiromancy', 'Phonomancy', 'Spatiomancy',
    'Tasseomancy', 'Theomancy',
}


def is_tool(s):
    return s.endswith("'s")


def is_circ(s):
    return '(' in s and ')' in s


def is_knowledge(s):
    if 'mancy' in s.lower():
        return True
    return s in KNOWLEDGE_KEYWORDS


def reconstruct_ancestry_row(parts):
    """Reconstruct an ancestry/bloodline row into correct 22 columns."""
    parts = [p.strip() for p in parts]

    name = parts[0]
    if not name:
        return None  # separator row

    # Find rarity position (col 2)
    rarity_pos = -1
    for i in range(1, len(parts)):
        if parts[i] in RARITIES:
            rarity_pos = i
            break

    if rarity_pos == -1:
        print(f"  WARNING: No rarity found for {name}, returning unchanged")
        return parts

    col1_bloodlines = ', '.join(p for p in parts[1:rarity_pos])
    col2_rarity = parts[rarity_pos]
    is_bloodline = (col1_bloodlines == '')

    remaining = parts[rarity_pos + 1:]

    # Remove trailing empties to find actual data end
    end = len(remaining) - 1
    while end >= 0 and remaining[end] == '':
        end -= 1
    data = remaining[:end + 1]

    if not is_bloodline:
        # ANCESTRY ROW: find life_exp (first numeric/N/A after rarity)
        life_pos = -1
        for i, v in enumerate(data):
            if v == 'N/A' or (v != '' and v.lstrip('-').isdigit()):
                life_pos = i
                break

        if life_pos == -1:
            print(f"  WARNING: No life_exp found for {name}")
            return parts

        perk_draw = data[:life_pos]
        col5_life = data[life_pos] if life_pos < len(data) else ''
        col6_dex = data[life_pos + 1] if life_pos + 1 < len(data) else ''
        col7_vig = data[life_pos + 2] if life_pos + 2 < len(data) else ''
        col8_size = data[life_pos + 3] if life_pos + 3 < len(data) else ''
        after_stats = data[life_pos + 4:]
    else:
        # BLOODLINE ROW: cols 5-8 are empty (life, dex, vig, size)
        col5_life = col6_dex = col7_vig = col8_size = ''

        # Find 4 consecutive empties to locate where perk_draw ends
        # Actually bloodline rows don't have numeric anchors.
        # Find the boundary: perk/drawback tokens come before types or empty run.
        # Types are TYPE_KEYWORDS. If not blank and not type, then they're perks/drawbacks.
        # After 4+ consecutive empty slots (cols 5-8), types may or may not be present.

        # Strategy: find 4+ consecutive empty slots
        consec_empty_start = -1
        for i in range(len(data)):
            # Check if we have at least 4 empties starting at i
            if i + 3 < len(data) and all(data[j] == '' for j in range(i, i + 4)):
                consec_empty_start = i
                break
            # Also: if remaining items look like types, we've found the boundary

        if consec_empty_start >= 0:
            perk_draw = data[:consec_empty_start]
            after_4_empties = data[consec_empty_start + 4:]
        else:
            # No 4 consecutive empties found - this means cols 5-8 + types/hybrid may be mixed
            # Fallback: find where types start
            perk_draw_end = 0
            while perk_draw_end < len(data) and data[perk_draw_end] not in TYPE_KEYWORDS and data[perk_draw_end] != '':
                perk_draw_end += 1
            perk_draw = data[:perk_draw_end]
            after_4_empties = data[perk_draw_end:]

        after_stats = after_4_empties

    # Split perk_draw into col3_perks and col4_drawbacks
    # Look for empty token as separator between perks and drawbacks
    sep_pos = -1
    for i, t in enumerate(perk_draw):
        if t == '':
            sep_pos = i
            break

    if sep_pos >= 0:
        col3_perks = ', '.join(t for t in perk_draw[:sep_pos] if t)
        col4_drawbacks = ', '.join(t for t in perk_draw[sep_pos + 1:] if t)
    else:
        # No separator: all are perks
        col3_perks = ', '.join(t for t in perk_draw if t)
        col4_drawbacks = ''

    # Parse after_stats: types(9), hybrid(10), knowledge(11), tool(12), circ(13), stat(14)

    # Collect types (TYPE_KEYWORDS) from start
    i = 0
    types_tokens = []
    while i < len(after_stats) and after_stats[i] in TYPE_KEYWORDS:
        types_tokens.append(after_stats[i])
        i += 1
    col9_types = ', '.join(types_tokens)

    # Work from the end to find stat, circ, tool, knowledge
    end_i = len(after_stats) - 1
    while end_i >= 0 and after_stats[end_i] == '':
        end_i -= 1

    # Collect stat_bonus (no apostrophe, no paren, not knowledge-specific)
    stat_tokens = []
    while end_i >= 0 and not is_tool(after_stats[end_i]) and not is_circ(after_stats[end_i]):
        stat_tokens.insert(0, after_stats[end_i])
        end_i -= 1
    col14_stat = ', '.join(stat_tokens)

    # Collect circumstance_odds (has parentheses)
    circ_tokens = []
    while end_i >= 0 and is_circ(after_stats[end_i]):
        circ_tokens.insert(0, after_stats[end_i])
        end_i -= 1
    col13_circ = ', '.join(circ_tokens)

    # Collect tool_odds (ends with "'s")
    tool_tokens = []
    while end_i >= 0 and is_tool(after_stats[end_i]):
        tool_tokens.insert(0, after_stats[end_i])
        end_i -= 1
    col12_tool = ', '.join(tool_tokens)

    # Remaining between types and tool start is: hybrid + knowledge
    middle = after_stats[i:end_i + 1]

    # Split middle into hybrid (col10) and knowledge (col11)
    # Hybrid comes first and is ancestry names or 'All'/'None'/''
    # Knowledge starts with known keywords or '-mancy' items
    hybrid_tokens = []
    k_start = 0
    for k_i, tok in enumerate(middle):
        if is_knowledge(tok):
            k_start = k_i
            break
        hybrid_tokens.append(tok)
    else:
        k_start = len(middle)

    col10_hybrid = ', '.join(hybrid_tokens)
    col11_knowledge = ', '.join(middle[k_start:])

    result = [
        name, col1_bloodlines, col2_rarity, col3_perks, col4_drawbacks,
        col5_life, col6_dex, col7_vig, col8_size, col9_types, col10_hybrid,
        col11_knowledge, col12_tool, col13_circ, col14_stat,
        '', '', '', '', '', '', ''  # 7 [Ignore] columns
    ]
    return result


def csv_quote(value):
    """Quote a CSV field if it contains a comma, quote, or newline."""
    if ',' in value or '"' in value or '\n' in value:
        return '"' + value.replace('"', '""') + '"'
    return value


def row_to_csv(fields):
    """Convert a list of field values to a CSV line."""
    return ','.join(csv_quote(f) for f in fields)


# Read the file
with open(r'u:\Game Design\MyProjects\MercManager\Godot\mercday\CSVs\Ancestries.csv', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines()

# Process each line
output_lines = []
output_lines.append(lines[0])  # Header unchanged

past_separator = False
for line_idx, line in enumerate(lines[1:], 2):
    parts = line.split(',')
    name = parts[0].strip()

    if not name:
        past_separator = True
        output_lines.append('')  # Keep separator row as empty line
        continue

    result = reconstruct_ancestry_row(parts)
    if result is None:
        output_lines.append('')
        continue

    output_lines.append(row_to_csv(result))
    print(f"Line {line_idx}: {name} -> {len(result)} cols")

# Verify Steeljoint
print("\nVerifying Steeljoint:")
for line in output_lines:
    if line.startswith('Steeljoint'):
        print(f"  {line[:200]}")
        break

print("\nVerifying Daemonborn:")
for line in output_lines:
    if line.startswith('Daemonborn'):
        print(f"  {line[:200]}")
        break

print("\nVerifying Dracipava:")
for line in output_lines:
    if line.startswith('Dracipava'):
        print(f"  {line[:200]}")
        break

print("\nVerifying Moet:")
for line in output_lines:
    if line.startswith('Moet'):
        print(f"  {line[:200]}")
        break

print("\nVerifying Dryad:")
for line in output_lines:
    if line.startswith('Dryad'):
        print(f"  {line[:200]}")
        break

print("\nVerifying Angelic:")
for line in output_lines:
    if line.startswith('Angelic'):
        print(f"  {line[:200]}")
        break
