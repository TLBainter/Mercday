"""
Test revised algorithm on all bloodline rows.
"""

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


def is_tool(s):
    return s.endswith("'s")


def is_circ(s):
    return '(' in s and ')' in s


def is_knowledge(s):
    if s == '':
        return False
    if 'mancy' in s.lower():
        return True
    return s in KNOWLEDGE_KEYWORDS


def parse_after_size(after_size):
    i = 0
    # Skip leading empties
    while i < len(after_size) and after_size[i] == '':
        i += 1
    # Collect TYPE_KEYWORD tokens
    type_start = i
    while i < len(after_size) and after_size[i] in TYPE_KEYWORDS:
        i += 1
    types = ', '.join(after_size[type_start:i])
    # Skip empties after types
    while i < len(after_size) and after_size[i] == '':
        i += 1
    # Collect hybrid (non-knowledge, non-tool, non-circ)
    hybrid_start = i
    while i < len(after_size) and not is_knowledge(after_size[i]) and not is_tool(after_size[i]) and not is_circ(after_size[i]):
        i += 1
    hybrid = ', '.join(t for t in after_size[hybrid_start:i] if t)
    # Rest is knowledge+tool+circ+stat (work from end backwards)
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


RARITIES = {'Common', 'Uncommon', 'Rare', 'Legendary', 'Very Rare'}
DRAWBACK_TERMS = {
    'Fragile Body', 'Lightweight', 'Photosensitive', 'Heat Averse', 'Cold Averse',
    'Crush Averse', 'Poison Averse', 'Unusual Look', 'Peaceable', 'Exposed',
    'Dragonfly Wings', 'Unwalkable', 'Shallowborn',
}


def split_perks_drawbacks(tokens):
    perks = []
    drawbacks = []
    # Drawbacks come after perks in the list
    # Use DRAWBACK_TERMS to identify where drawbacks start
    in_drawbacks = False
    for t in tokens:
        if t in DRAWBACK_TERMS:
            in_drawbacks = True
        if in_drawbacks:
            drawbacks.append(t)
        else:
            perks.append(t)
    return ', '.join(perks), ', '.join(drawbacks)


with open(r'u:\Game Design\MyProjects\MercManager\Godot\mercday\CSVs\Ancestries.csv', 'r', encoding='utf-8') as f:
    content = f.read()
lines = content.splitlines()

print("=== Testing all bloodline rows ===")
for line_idx, line in enumerate(lines[1:], 2):
    parts = [p.strip() for p in line.split(',')]
    name = parts[0]
    if not name:
        continue
    rarity_pos = -1
    for j in range(1, len(parts)):
        if parts[j] in RARITIES:
            rarity_pos = j
            break
    if rarity_pos < 0:
        continue
    is_bloodline = (parts[1].strip() == '')
    if not is_bloodline:
        continue
    remaining = parts[rarity_pos+1:]
    consec = -1
    for j in range(len(remaining)):
        if all(k < len(remaining) and remaining[k] == '' for k in range(j, j+4)):
            consec = j
            break
    if consec >= 0:
        perk_draw = remaining[:consec]
        after_size_raw = remaining[consec+4:]
    else:
        perk_draw = []
        after_size_raw = remaining

    # Remove trailing 7 empties
    e = len(after_size_raw)
    while e > 0 and after_size_raw[e-1] == '':
        e -= 1
    after_size = after_size_raw[:e]

    # Split perk_draw by separator or drawback terms
    perk_draw_nonempty = [t for t in perk_draw if t != '']
    sep_pos = next((i for i, t in enumerate(perk_draw) if t == ''), -1)
    if sep_pos >= 0:
        perks = ', '.join(t for t in perk_draw[:sep_pos] if t)
        drawbacks = ', '.join(t for t in perk_draw[sep_pos+1:] if t)
    else:
        perks, drawbacks = split_perks_drawbacks(perk_draw_nonempty)

    types, hybrid, knowledge, tool, circ, stat = parse_after_size(after_size)
    print(f"L{line_idx} {name}: perks={perks!r}, drawbacks={drawbacks!r}, types={types!r}, hybrid={hybrid!r}, stat={stat!r}")
