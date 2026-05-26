"""
Test the corrected algorithm for after_4 parsing.
"""

TYPE_KEYWORDS = {'Hominid', 'Elemental', 'Beast', 'Fey', 'Daemon', 'Assembly', 'Plant', 'Undead', 'Ethereal'}

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
    'Tasseomancy', 'Theomancy', 'Magic',
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
    """Parse types, hybrid, knowledge, tool, circ, stat from after_size tokens."""
    # Collect types (TYPE_KEYWORDS from start)
    i = 0
    while i < len(after_size) and after_size[i] in TYPE_KEYWORDS:
        i += 1
    types = ', '.join(after_size[:i])

    # Skip consecutive empties (these are extra empty slots for size/types/hybrid)
    while i < len(after_size) and after_size[i] == '':
        i += 1

    # Collect non-knowledge, non-tool, non-circ items as hybrid
    hybrid_start = i
    while i < len(after_size) and not is_knowledge(after_size[i]) and not is_tool(after_size[i]) and not is_circ(after_size[i]):
        i += 1
    hybrid = ', '.join(t for t in after_size[hybrid_start:i] if t)

    # Rest is knowledge + tool + circ + stat (work from end)
    remaining = after_size[i:]
    end_i = len(remaining) - 1
    while end_i >= 0 and remaining[end_i] == '':
        end_i -= 1

    stat_tokens = []
    while end_i >= 0 and not is_tool(remaining[end_i]) and not is_circ(remaining[end_i]):
        stat_tokens.insert(0, remaining[end_i])
        end_i -= 1
    stat = ', '.join(stat_tokens)

    circ_tokens = []
    while end_i >= 0 and is_circ(remaining[end_i]):
        circ_tokens.insert(0, remaining[end_i])
        end_i -= 1
    circ = ', '.join(circ_tokens)

    tool_tokens = []
    while end_i >= 0 and is_tool(remaining[end_i]):
        tool_tokens.insert(0, remaining[end_i])
        end_i -= 1
    tool = ', '.join(tool_tokens)

    knowledge_tokens = remaining[:end_i+1]
    knowledge = ', '.join(knowledge_tokens)

    return types, hybrid, knowledge, tool, circ, stat


# Test cases
test_cases = [
    ('Angelic_after4', ['', '', '', 'Theomancy', 'Daemon', 'Immortal', 'Primeval', 'Pre-Reckoning', 'Theology',
                        "Cartomancer's", "Exorcist's", "Missionary's", "Godslayer's",
                        'Speech (Wile)', 'Grace (Dexterity)', 'Performance (Dexterity)', 'Presence (Vigor)', 'Presence (Wile)',
                        'Social', 'Zealotry']),
    ('Vaettir_after4', ['', '', 'Magic', 'Oneiromancy', 'Hunting', 'Fey', 'Umbra', 'Reconnaissance', 'Cavern',
                        'Undercity', 'Lowborn',
                        "Transmuter's", "Scavenger's", "Assassin's", "Tracker's", "Calligrapher's",
                        "Tattoo Artist's", "Cipherist's", "Scout's", "Navigator's", "Climber's",
                        "Survivalist's", "Archaeologist's", "Mortician's",
                        'Finesse (Dexterity)', 'Grace (Dexterity)', 'Intuition (Cognition)', 'Notice (Cognition)',
                        'Presence (Vigor)', 'Resist (Cognition)', 'Resist (Dexterity)', 'Resist (Vigor)',
                        'Search (Cognition)', 'Spellcast (Cognition)', 'Spellcast (Dexterity)', 'Spellcast (Vigor)',
                        'Cheat Death', 'Maximum Magic Points']),
    ('Dryad_after4', ['', 'Fey', 'Hominid', 'Plant', '', 'Geomancy', 'Agriculture', 'Culinary', 'Plant',
                      'Music', 'Weird', 'Aerdis', 'Forest', 'Mythozoology', 'Marsh', 'Tropical', 'Chivalry',
                      "Weaver's", "Artist's", "Musician's", "Falconer's", "Groomer's", "Poisoner's",
                      "Survivalist's", "Herbologist's",
                      'Athletics (Vigor)', 'Grace (Dexterity)', 'Finesse (Dexterity)', 'Performance (Dexterity)',
                      'Performance (Wile)', 'Presence (Wile)', 'Spellcast (Wile)', 'Resist (Wile)',
                      'Rest Recovery']),
    ('Toadstool_after4', ['Fey', 'Hominid', 'Plant', '', 'Geomancy', 'Hydromancy', 'Magic', 'Forestry',
                          'Culinary', 'Comedy', 'Plant', 'Fey', 'Forest', 'Marsh', 'Tropical', 'Undercity',
                          'Aerdis', 'Suorr', 'Biology', 'Botany', 'Weird', 'Geology', 'Travel',
                          'Domain Walking', 'Education', 'Lowborn', 'Diplomacy', 'Necromancy',
                          "Book Binder's", "Chef's", "Gardener's", "Potter's", "Tailor's", "Weaver's",
                          "Woodcarver's", "Calligrapher's", "Cipherist's", "Scout's", "Navigator's",
                          "Survivalist's", "Alchemist's", "Herbologist's", "Surgeon's", "Mortician's",
                          "Missionary's", "Dealer's", "Archaeologist's", "Cartographer's",
                          'Clever (Cognition)', 'Intuition (Cognition)', 'Performance (Wile)',
                          'Resist (Cognition)', 'Search (Cognition)', 'Spellcast (Cognition)',
                          'Maximum Magic Points', 'Support']),
]

for name, after_size in test_cases:
    types, hybrid, knowledge, tool, circ, stat = parse_after_size(after_size)
    print(f"\n{name}:")
    print(f"  types={types!r}")
    print(f"  hybrid={hybrid!r}")
    print(f"  knowledge (first 60)={knowledge[:60]!r}")
    print(f"  tool (first 40)={tool[:40]!r}")
    print(f"  circ (first 40)={circ[:40]!r}")
    print(f"  stat={stat!r}")
