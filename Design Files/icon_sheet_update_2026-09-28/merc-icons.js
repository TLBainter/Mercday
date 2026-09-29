// Merc Manager icon atlas (icon_sheet/merc-manager_ICON-COLLECTION.png, 16×40 cells of 16 px).
// Generated from the atlas. Each entry: [col, row, x, y, w, h, mono, palette, pixels]
//   x,y,w,h = trimmed box inside the 16 px cell; mono = 1 if every pixel is gray (tint with modulate).
// API: MercIcons.cells(id, tint?, force?) → w*h CSS colors. Mono icons are multiplied by tint (like Godot modulate);
//      color icons ignore tint unless force = true (then they are grayscaled first, e.g. dark icon on an active orange tab).
//      MercIcons.cell16(id, tint?) → 256 CSS colors: the full 16×16 cell at its atlas offset (use for tabs, buttons, nodes)
//      MercIcons.box(id, x, y, w, h, tint?, force?) → a w×h window of the 16×16 cell (e.g. the centered 8×8 of a small icon)
//      MercIcons.solid(id, color) → trimmed w*h, every opaque pixel = color (e.g. pure-white check on a button)
//      MercIcons.diffStar(fill 0|0.5|1, color, empty?) → 256 cells, difficulty star
//      MercIcons.tabOn(id) → 256 cells, two-tone dark version for the active orange tab
//      MercIcons.mask(id, ch='#', darkCh?) → rows with ch on opaque pixels ('.' = empty); darkCh marks dark pixels separately
//      MercIcons.w(id), .h(id), .info(id)
(function () {
  const D = {"mercs":[0,0,0,1,16,14,0,"#8a97ad,#ffffff","...aa......aa.....aaaa....aaaa....aaaa....aaaa.....aa.bbbb.aa....aaa.bbbbbb.aaa.aaaa.bbbbbb.aaaaaaaa.bbbbbb.aaaaaaaa..bbbb..aaaaaaaa........aaaaaaa...bbbb...aaa....bbbbbbbb.......bbbbbbbbbb......bbbbbbbbbb......bbbbbbbbbb..."],
    "contracts":[1,0,2,2,13,13,0,"#ffffff,#8a97ad,#e8583f","aaaaaaaaaaaa.aaaaaaaaaaaa.abbbbbbbbbba.aaaaaaaaaaaa.abbbbbbbbaaa.aaaaaaaaaaaa.abbbbbbbaaaa.aaaaaaaaaaaa.abbbbbbaaaaa.aaaaaaaaaacc.abbbbbaaaccccaaaaaaaaaccccaaaaaaaaaacc."],
    "clients":[2,0,1,4,14,11,0,"#ffffff,#8a97ad","..aaaa.........aaaaaa..bbbb..aaaaaa.bbbbbb.aaaaaa.bbbbbb..aaaa..bbbbbb.........bbbb...aaaa........aaaaaaaa.bbbb.aaaaaaaabbbbbbaaaaaaaabbbbbbaaaaaaaabbbbbb"],
    "promotions":[3,0,1,2,15,12,0,"#f28c28,#f28d28,#ffffff,#8a97ad,#e8583f",".........ab...........aaca.........aaccaa..d.aaaaaccccae.d..accccccccae....accccccccae.dddaccccccccae....aaaaaccccae.d...aa..aaccaa..d..aa....aaca.....aa......aa.....aa............"],
    "mercday":[4,0,1,1,14,14,0,"#f28c28,#e8583f,#ffffff","....aaaaaa......aa......aa...a..........a.a....bbbb....a....b....b.....cc........cc..ccc......ccc..cccc....cccc..cc.cc..cc.cc..cc..cccc..cc..cc...cc...cc..cc........cc..cc........cc..cc........cc."],
    "finance":[5,0,3,1,11,14,0,"#ffffff,#8a97ad","....aab........aab....aab.aaaab..aab.aaaab..aaaaaab.aabaaaaaab.aabaab.aab.aabaab.aab.aabaab.aab.aabaab.aab.aabaab.aab.aabaab.aab.aab....aab........aab...."],
    "legal":[6,0,2,2,14,13,0,"#ffffff,#e8583f,#f28c28","....aaaa.........abbbba.........acca..........acca..........acaccccccc....acca..........acca......b..abbbba..b......aaaa........b......b.......aaaaaa.......aaccccaa....aaaaaaaaaaaa.."],
    "bazaar":[7,0,1,1,14,14,0,"#f28c28,#ffffff,#8a97ad","aabbaabbaabbaaaabbaabbaabbaaaabbaabbaabbaa...............b..........b..b..........b..b..........b..baaaaaaaaaab..baaaaaaaaaab.bbbbbbbbbbbbbbb............bb.cc..cc..cc.bb.cc..cc..cc.bbbbbbbbbbbbbbb"],
    "metrics":[8,0,1,1,14,14,0,"#ffffff,#8a97ad,#f28c28","a........bbbbba..........bbba.........bbbba........bbb.ba...bb...bb..ba..bbbb.bb....a.bb.bbbbb.cc.abb...bbb..cc.ab.........cc.a.......cc.cc.a....cc.cc.cc.a.cc.cc.cc.cc.a.cc.cc.cc.cc.aaaaaaaaaaaaaa"],
    "bell":[9,0,0,0,16,15,0,"#ffffff,#f28c28,#e8583f",".......aa.............aaaa..........aaaaaaaa.......aaaaaaaaaa......aaaaaaaaaa......aaaaaaaaaa......aaaaaaaaaa......aaaaaaaaaa.....aaaaaaaaaaaa...aaaaaaaaaaaaaa..aaaaaaaaaaaaaa.aaaaaaaaaaaaaaaa.....bccccb...........bbbb.............bb......."],
    "gear":[10,0,0,0,16,16,1,"#ffffff,#feffff",".......aa........aa...aaaa...aa..aaa..aaaa..aaa...aaaaaaaaaaaa.....aaaaaaaaaa......aaaa..aaaa....aaaaa....aaaaa.aaaaa......aaaaaaaaaa......aaaaa.aaaaa....aaaaa....aaaa..aaaa......aaaaaaaaaa.....aaaaaaaaaaaa...aaa..abaa..aaa..aa...aaaa...aa........aa......."],
    "dot":[11,0,4,4,8,8,1,"#dadada,#f0efee,#ffffff,#909090","..abcc...abcccc.abccccccabccccccdabccccbdaabccba.daabba...ddaa.."],
    "ring8":[12,0,4,4,8,8,1,"#ffffff","..aaaa...aa..aa.aa....aaa......aa......aaa....aa.aa..aa...aaaa.."],
    "ring10":[13,0,3,3,10,10,1,"#ffffff,#fffeff","...aaaa....aa....aa..a......a.b........aa........aa........aa........a.a......a..aa....aa....aaaa..."],
    "ring12":[14,0,2,2,12,12,1,"#ffffff","...aaaaaa.....aa....aa...aa......aa.aa........aaa..........aa..........aa..........aa..........aaa........aa.aa......aa...aa....aa.....aaaaaa..."],
    "ring14":[15,0,1,1,14,14,1,"#ffffff","....aaaaaa.......aa....aa.....a........a...a..........a.aa..........aaa............aa............aa............aa............aaa..........aa.a..........a...a........a.....aa....aa.......aaaaaa...."],
    "speed_slow":[0,1,4,4,8,7,1,"#ffffff","...a...a..aa..aa.aaa.aaaaaaaaaaa.aaa.aaa..aa..aa...a...a"],
    "pause":[1,1,5,4,5,7,1,"#ffffff","aa.aaaa.aaaa.aaaa.aaaa.aaaa.aaaa.aa"],
    "play":[2,1,6,4,4,7,1,"#ffffff","a...aa..aaa.aaaaaaa.aa..a..."],
    "speed_fast":[3,1,4,4,8,7,1,"#ffffff","a...a...aa..aa..aaa.aaa.aaaaaaaaaaa.aaa.aa..aa..a...a..."],
    "speed_faster":[4,1,2,4,12,7,1,"#ffffff","a...a...a...aa..aa..aa..aaa.aaa.aaa.aaaaaaaaaaaaaaa.aaa.aaa.aa..aa..aa..a...a...a..."],
    "caret_down":[5,1,5,6,5,3,1,"#ffffff","aaaaa.aaa...a.."],
    "caret_up":[6,1,5,6,5,3,1,"#ffffff","..a...aaa.aaaaa"],
    "caret_right":[7,1,7,5,3,5,1,"#ffffff","a..aa.aaaaa.a.."],
    "caret_left":[8,1,6,5,3,5,1,"#ffffff","..a.aaaaa.aa..a"],
    "filter":[9,1,5,5,5,5,1,"#ffffff","aaaaa......aaa........a.."],
    "plus":[10,1,6,5,5,5,1,"#ffffff","..a....a..aaaaa..a....a.."],
    "minus":[11,1,6,7,5,1,1,"#ffffff","aaaaa"],
    "trend_up":[12,1,4,4,7,8,0,"#6cc36a","...a.....aaa...aaaaa.aaaaaaa..aaa....aaa....aaa....aaa.."],
    "trend_diag_up":[13,1,3,4,8,8,0,"#6cc36a","...aaaaa.....aaa....aaaa...aaa.a..aaa..a.aaa....aaa.....aa......"],
    "trend_diag_down":[14,1,3,4,8,8,0,"#ff3b2f","aa......aaa......aaa......aaa..a...aaa.a....aaaa.....aaa...aaaaa"],
    "trend_down":[15,1,4,4,7,8,0,"#ff3b2f","..aaa....aaa....aaa....aaa..aaaaaaa.aaaaa...aaa.....a..."],
    "x_lg":[0,2,2,2,12,12,0,"#ff3b2f","aa........aaaaa......aaa.aaa....aaa...aaa..aaa.....aaaaaa.......aaaa........aaaa.......aaaaaa.....aaa..aaa...aaa....aaa.aaa......aaaaa........aa"],
    "check_lg":[1,2,2,2,13,10,0,"#6cc36a","...........aa..........aaa.........aaaa........aaaa.aa.....aaaa..aaa...aaaa...aaaa.aaaa.....aaaaaaa.......aaaaa.........aaa......."],
    "x_sm":[2,2,3,3,10,10,0,"#ff8a70,#ff3b2f,#a83a28",".a......a.abc....abc.abc..abc...abcabc.....abbc......abbc.....abccbc...abc..abc.abc....abc.a......a."],
    "check_sm":[3,2,3,3,11,10,0,"#9be29a,#6cc36a,#123321",".........a.........abc.......abbc.a....abbbcabc..abbbc.abbcabbbc...abbbbbc.....abbbc.......abc.........a......"],
    "alert":[4,2,6,3,4,10,0,"#f28c28",".aa.aaaaaaaaaaaaaaaa.aa..aa......aa..aa."],
    "thumbs_down":[5,2,0,0,15,16,0,"#ff8a70,#ff3b2f,#fe8a70","............aa...aaaaaaa..abba.abbbbbbba.abbaabbbbbbbbc.abba.aabbbbbba.abbaabbbbbbbba.abba.aaabbbbba.abbaabbbbbbbba.abba.aaaabbbba.abbaabbbbbbbba.abba.aaaabbba...aa......abba...........abba...........abba...........abba............aa......."],
    "thumbs_up":[6,2,1,0,15,16,0,"#9be29a,#6cc36a",".......aa............abba...........abba...........abba...........abba......aa...abbbaaaa.abba.abbbbbbbbaabba.abbbbaaaa.abba.abbbbbbbbaabba.abbbbbaaa.abba.abbbbbbbbaabba.abbbbbaaa.abba.abbbbbbbbaabba.abbbbbbba.abba..aaaaaaa...aa............"],
    "prohibited":[7,2,0,0,16,16,0,"#ff3b2f","......aaaa..........aaaaaaaa.......aaaaaaaaaa.....aaaa....aaaa...aaaaaa....aaaa..aaaaaaa....aaa.aaa.aaaaa....aaaaaa..aaaaa...aaaaaa...aaaaa..aaaaaa....aaaaa.aaa.aaa....aaaaaaa..aaaa....aaaaaa...aaaa....aaaa.....aaaaaaaaaa.......aaaaaaaa..........aaaa......"],
    "skull":[8,2,3,2,11,13,0,"#ff8a70,#ff3b2f,#a83a28","..aaaaaaa...abbbbbbba.abbbbbbbbbabbbbbbbbbbcbbcbbbbbcbcbb.cbbbc.bcbbaabbbaabcbbbbbbbbbbc.bbbcbcbbc...bbababc....bbbbbbc....bcbcbcc....bacacac.."],
    "bars":[9,2,0,0,16,16,0,"#000000,#ffffff,#34415e,#8a97ad,#dadada","aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbcdccdccdcecececeeeeeeeeeeededede.d..d..d.e.e.e.e.d..d..d.e.e.e.eeeeeeeeeeededbbb.d..d..d.e.e.ece.d..d..d.e.e.eeeeeeeeeeeeededede.d..d..d.e.e.e.e.d..d..d.e.e.e.edddddddddeeeeeeeccccccccccccccccaaaaaaaaaaaaaaaa"],
    "note":[14,2,5,3,5,9,1,"#ffffff","..a....a..a.aa.aaa.aa.a.aa.a.aa.a.aa.a.a..a.."],
    "lock":[15,2,4,3,8,9,1,"#ffffff,#909090","..aaab...ab..ab..ab..ab.aaaaaaabaabbbaabaabbbaabaaabaaabaaabaaabaaaaaaab"],
    "eye":[0,3,2,4,12,8,0,"#000000,#ffffff,#8a97ad,#010000","....aaaa......aabbbbaa...abbbccbbba.abbbcaacbbbaabbbcaacbbba.abbbccbbba...dabbbbaa......aaaa...."],
    "tree":[1,3,2,2,12,13,0,"#000000,#6cc36a,#7a4a1a","....aaaa......aabbbbaa...abbbbbbbba.abbbbbbbbbbaabbbbbbbbbba.abbbbbbbba...aabbbbaa......acca........acca........acca.......acccca.....acccccca.....aaaaaa..."],
    "arrow_up_green":[2,3,2,1,12,14,0,"#000000,#6cc36a",".....aa.........abba.......abbbba.....abbbbbba...abbbbbbbba.abbbbbbbbbba.aaabbbbaaa....abbbba......abbbba......abbbba......abbbba......abbbba......abbbba.......aaaa...."],
    "arrow_down_red":[3,3,2,1,12,14,0,"#000000,#ff3b2f,#ff3b2e","....aaaa.......abbbba......abbbba......abbbba......abbbba......abbbba......abbbba....aaabbbbaaa.abbbbbbbbbba.abbbbbbbba...abbbcbba.....abbbba.......abba.........aa....."],
    "backpack":[4,3,1,2,14,13,0,"#ffb266,#000000,#8a5a2a,#7a4a1a","......aa...........a..a.........bbbbbb.......bccccccb.....bcacacacab....bacacacacb....bccccccccb...bbccccccccbb.bdbcaaaaaacbdbbdbcaccccacbdbbdbcaccccacbdbbdbccaaaaccbdb.bbbbbbbbbbbb."],
    "smiley":[5,3,2,2,12,12,0,"#000000,#3b6fb6","...aaaaaa.....abbbbbba...abbbbbbbba.abbaabbaabbaabbabbbbabbaabbbbbbbbbbaababbbbbbabaababbbbbbabaabbabbbbabba.abbaaaabba...abbbbbba.....aaaaaa..."],
    "fist":[6,3,1,0,14,15,0,"#000000,#e6d3a2,#c9b27a","...aa.aa........abbabbaaa.....abbabbabbaa..aabbabbabbabaacabbabbabbabaacaccaccaccabaabcaacaacaaacaabbccbccbcccaa.abbbbbbbbbbca..abbbbbbbbbba...acbbbbbbca.....accbbbca......abbbbbba......abbbbbba.......aaaaaa..."],
    "whistle":[7,3,1,0,14,16,0,"#000000,#f28c28,#e8583f,#8a97ad","...aa...........abba.........abbbba.......acabbbba......accabbbbaa.....accabbbada.....accabaddda.....accadddaba....acccadabbba..acccccabbbba..accccccabbba..accccccabbba..accccccabba...accccccaba.....accccaba.......aaaaaa...."],
    "guild_banner":[8,3,3,2,10,13,0,"#f2d33d,#f2d23d,#8a97ad,#ffffff","aaaaaaaaaaaaaaaaaabaaaccccccaaaacddddcaaaacddddcaaaaccccccaaaaaaaaaaaaaaaaaaaaaaaaaa..aaaaaaa....aaaaaa....aaaaa......aaa........a"],
    "pip_auto":[9,3,4,4,8,8,0,"#ffffff,#f28c28","..aaaa...a....a.a..bb..aa.b..b.aa.bbbb.aa.b..b.a.a....a...aaaa.."],
    "pip_random":[10,3,4,4,8,8,0,"#ffffff,#f28c28,#fffeff","aaaaaaaaa......aa.b..b.aa......aa......aa.b..b.aa......aaaaacaaa"],
    "pip_utility":[11,3,4,4,8,8,0,"#f28c28,#ffffff","....aa......a......aa..a...baaaa..bbba...bbb....b.b.....bb......"],
    "pip_stats":[12,3,4,4,8,8,0,"#ffffff,#f28c28",".....aaa......aa.....a.a...aa....aa...bba..bb.bbbb.bb.bbaaaaaaaa"],
    "pip_support":[13,3,4,4,8,8,0,"#ffffff,#f28c28",".aa..aa.abb..bbab..bb..bb..bb..b.bb..bb..........aaaaaa.aaaaaaaa"],
    "pip_defensive":[14,3,4,4,8,8,0,"#ffffff,#f28c28","aaaaaaaaa......aa.bbbb.aa.bbbb.aa..bb..a.a.bb.a..a....a...aaaa.."],
    "pip_offensive":[15,3,4,4,8,8,0,"#f28c28,#ffffff","......aa.....aaa....aaa.b.baaa...bbaa.....bbb....b.b....b...b..."],
    "person_outline":[0,4,1,1,14,14,1,"#ffffff,#fffffe",".....aaaa.........a....a.......a......a......a......a......a......a......a......a.......aaaaaa......................aaaaaa.....aaa......aaa.a............aa............aa............aaaaaaaaaaaabaa"],
    "person":[1,4,1,1,14,14,1,"#ffffff",".....aaaa.........aaaaaa.......aaaaaaaa......aaaaaaaa......aaaaaaaa......aaaaaaaa.......aaaaaa......................aaaaaa.....aaaaaaaaaaaa.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
    "house":[2,4,1,1,14,14,1,"#ffffff","......aa...........a..a.........a.aa.a.......a.aaaa.a.....a.aaaaaa.a...a.aaaaaaaa.a.a.aaaaaaaaaa.a.aaaaaaaaaaaa..aaa......aaa..aaa.aaaa.aaa..aaa.aaaa.aaa..aaa.aaaa.aaa..aaa.aaaa.aaa..aaaaaaaaaaaa."],
    "building":[3,4,1,1,14,14,1,"#ffffff","...aaaaaaaa......aa.aa.aa......aaaaaaaa......aa.aa.aa......aaaaaaaa...aaaaaaaaaaaaaaaa.aa.aa.aa.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.aa.aa.aa.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.aa.aa.aa.aaaaaaaaaaaaaaaa"],
    "wom":[4,4,2,4,12,8,0,"#ffffff,#f28c28",".aaaaaaaaaa.aaaaaaaaaaaaaabbabbabbaaaaaaaaaaaaaa.aaaaaaaaaa....aaa........aa.........a.........."],
    "flyers":[5,4,4,3,8,10,0,"#ffffff,#f28c28","aaaaaaaaaaabbaaaaaaaaaaaabbbbbbaaaaaaaaaabbbabbaaaaaabbaabbbabbaaaaaaaaaaaaaaaaa"],
    "direct_sale":[6,4,3,2,10,11,0,"#f28c28,#ffffff,#feffff","....aa.......aaaa...bbbbbbbbbbbaabbbbaabbaabbbbaabbbbcbbbbbbbaabbbbaabbaabbbbaabbbbbbbbbbbbbbbaabbbbbbbbaabbbb"],
    "radio":[7,4,3,3,10,10,0,"#f28c28,#ffffff","........a........a........a...bbbbbbbbbbbaaaabbbbbbabbabbaabbaaaabbaabbabbabbbbbbaaaabbbbbbbbbbbbbbb"],
    "sponsorship":[8,4,3,3,10,10,0,"#ffffff,#f28c28","a.........aaaaaaaaaaabbbbbbbbaabaaaaaabaabbbbbbbbaaaaaaaaaaaa.........a.........a.........a........."],
    "pip_skills":[9,4,5,4,6,7,0,"#ffffff,#f28c28","aaaaaaa....aabbbbaa....aabbb.aa....aaaaaaa"],
    "pip_existing":[10,4,4,4,7,7,0,"#ffffff,#f28c28",".aaaaaa.ab...a.b....abbbbbbb.b....a.ab...a.aaaaaa"],
    "pip_new":[11,4,5,4,6,7,0,"#ffffff,#f28c28,#f38c28","aabbaaa.bb.aabbbbabbcbbbabbbbaa.bb.aaabbaa"],
    "pip_universal":[12,4,4,4,8,8,0,"#ffffff,#f28c28",".aabaaa..a.bb.a..ab..ba.bb.bb.bb.b.bb.b..ab..ba..a.bb.a..aaabaa."],
    "pip_ancestral":[13,4,5,4,6,8,0,"#ffffff,#f28c28","abbbbabbabbbbbbbbbbabbababbbbaa.bb.aa.bb.aabbbba"],
    "pip_tradition":[14,4,4,4,8,8,0,"#ffffff,#f28c28",".aaaaaa.bbbbbbbbbbb..bbbbbb..bbbbbb..bbbbb....bbba....abbaaaaaab"],
    "pip_spell":[15,4,4,4,8,8,0,"#ffffff,#f28c28",".aabbaa..abbbba.bbbbbbbb.bbbbbb..abbbba..bb..bb.bb....bb.aaaaaa."],
    "money_bag":[0,5,1,1,14,14,0,"#e6d3a2,#8a5a2a,#000000","....aa...aa........aaaaa..........bbb.........aaaaaaa......aaaacaaaa....aaaaacaaaa...aaaacaccaaaa..aaaacccacaaa.aaaaacacacaaaaaaaaacacacaaaaaaaaacacacaaaabaaaacacacaaab.bbaaaacaaaab....bbbbbbbbb.."],
    "add_person":[1,5,3,4,13,11,0,"#ffffff,#6cc36a,#6cc36b","...aaaa..bb....aaaaaa.bb....aaaaabbbbbb..aaaaabbbbcb...aaaa..bb...........bb.....aaaa.......aaaaaaaa....aaaaaaaaaa...aaaaaaaaaa...aaaaaaaaaa..."],
    "invest":[2,5,2,4,13,10,0,"#6cc36a,#ffffff",".........aaaa...........aa....a.....a.a...a.a...a..a..a...a.a.....a.....a..bb.a.........bb...........bb.....bb....bb..bb.bb.bb.bb."],
    "piggy":[3,5,0,3,15,12,0,"#ffd87a,#a8385a,#f07ab8,#f2d33d,#8a5a2a,#ff8a70","........aaa.......b..caddda......ccccdeeedff....bcbcbbbbbccf.fbbcccfcffcccffcccbccfffcfccbbbcbbccfcfcfccbbcccbccfcfcfccb.bbbcccccfccccb....bcccbbcccb.....bccb..bccb......bbb..bbb.."],
    "sun_low":[4,5,1,10,14,6,0,"#e8583f",".....a..a........a......a....a..........a.....aaaaaa....a..aaaaaaaa..a..aaaaaaaaaa.."],
    "sun_rising":[5,5,0,5,16,11,0,"#f2d33d,#f28c28,#e8583f","........a..............aa............a.a..a.......a..a....a..a.....a.bbbbbb.a...a...b......b...a.a.b.cccccc.b.a...b.cccccccc.b...b.cccccccccc.b..b.cccccccccc.b..b.cccccccccc.b."],
    "sun_full":[6,5,0,0,16,16,0,"#f2d33d,#f28c28,#e8583f",".......a..........................a..bbaabb......a..aaaaaaab..a....aaaccccaaa.....baacaaaacaaa.a..baaaabbaaaaa....bacabaabacab....bacabaabacab....baaaaaaaacab....baacaaaacaab.....aaaccacaab...a...baaaaaab.....a...bbaabb............................a..a....."],
    "customize":[7,5,3,3,10,10,0,"#ffffff,#f28c28",".aa....bb..aa....bb.aaaa..bbbb.aa....aa..aa....aa..aa....aa..aa....aa.bbbb..aaaa.bb....aa..bb....aa."],
    "shop":[8,5,1,1,14,15,0,"#f28c28,#ffffff,#8a97ad,#e6d3a2",".aabbaabbaabb..aabbaabbaabb..aabbaabbaabb..cccccccccccc..dbbbbbbbbbbd..dbccbbbbccbd..dbccbbbbccbd..dbccbbbbccbd..dbbbbbbbbbbd..dbbddddddbbd..dbbdccccdbbd..dbbdccccdbbd..dbbdcccddbbd..dbbdccccdbbd.dddddddddddddd"],
    "cart":[9,5,0,1,16,14,0,"#f28c28,#e6d3a2,#ffffff,#fffffe,#e8583f","aa................b...............b................bbbbbbbbbbbbb...bcaccaccadcab....bcaccaccacb.....bcaccaccacb......bcaccaccb.......bbbbbbbb........b...............bbbbbbb.........a.....a........aea...aea........a.....a...."],
    "parcel":[10,5,1,2,14,12,0,"#e6d3a2,#e8583f,#ffffff,#f28c28","...aabbbaaa.....acbbbcccca...acbbbcccccca.aaadddaaaaaaaaaccdddcccccccaaccdddcccccccaaccdddcccccccaaccdddcccccccaacccddcccccccaaccccdcccccccaaccccccccccccaaaaaaaaaaaaaaa"],
    "permit":[11,5,1,1,14,15,0,"#000000,#ffffff,#f28c28,#e8583f","aaaaaaaaaaaaa.abbbbbbbbbbba.abcccccccccba.abbbbbbbbbbba.abccccccccbba.abbbbbbbbbbba.abcccccccbbba.abbbbbbbbbbba.abccccccbdbda.abbbbbbdbbbbd.abcccccbbddba.abbbbbbbdddda.abbbbbbbddddadaaaaaaadadddd.........d..ddd"],
    "coin":[12,5,1,1,14,14,0,"#000000,#f28c28,#ffffff,#e8583f,#010000","....abbbbb.......abcccccb.....abcccdcccb...abccccdccccb..abccdcddcccb.abcccdddcdcccbabcccdcdcdcccbabcccdcdcdcccbebcccdcdcdcccb.abccdcdcdccb..abccccdccccb...abcccccccb.....abcccccb.......abbbbb...."],
    "bail_bars":[13,5,2,1,12,14,0,"#e8583f,#ffffff,#f28c28,#f28d28","aaaaaaaaaaaabbbbbbbbbbbbcaadababababbbbbbbcbcbcbc..c.b.b.b.bc..c.b.b.b.bbbbbbbcbcbbbc..c.b.b.babc..c.b.b.bbbbbbbbbcbcbcbc..c.b.b.b.bc..c.b.b.b.bcccccbbbbbbbaaaaaaaaaaaa"],
    "job_ads":[14,5,2,0,14,15,0,"#f28c28,#8a97ad,#ffffff","......a..............a..a.........ba.a.......a.ccb....a....a.cccb..a......bccccb........bcccccbaa....ccbcccccb.a...cccbcccc.....cccccbb......cccccc..aa...ccccb.........bccbbb.........bc.bbb............bb......."],
    "guild_ads":[15,5,1,1,14,15,0,"#f28c28,#ffffff,#8a97ad",".aaaaaaaaaaaa..abbbbbbbbbba..abaaabbaaaba..abaaabbbbbba..abaaabbaabba..abbbbbbbbbba..abaaabbaaaba.cccccccccccccc.c.c.cbbc.......c..cbbc......c.c.cbbc.......c..cbbc......c.c.cbbc.......c..cbbc......c.c.cbbc....."],
    "face_unselected":[0,7,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a..aa..aa..aa..aa..aa..aa..........aa..........aa...aaaa...aa..........a.a........a...a......a.....aaaaaa..."],
    "face_m5":[1,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbabbbbabbaabbaabbaabbaabbbbbbbbbbaabbbbbbbbbbaabbbaaaabbbaabbaaaaaabba.ababbbbaba...abbbbbba.....aaaaaa..."],
    "face_m4":[2,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbabbbbabbaabbbabbabbbaabbbbbbbbbbaabbbbbbbbbbaabbbaaaabbbaabbabbbbabba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_m3":[3,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbbabbabbbaabbbbbbbbbbaabbbbbbbbbbaabbbaaaabbbaabbabbbbabba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_m2":[4,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbaabbaabbaabbbbbbbbbbaabbbbbbbbbbaabbbbaabbbbaabbbabbabbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_m1":[5,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbabbbbabbaabbbbbbbbbbaabbbbbbbbbbaabbbaaabbbbaabbabbbbbbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_0":[6,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbbabbabbbaabbbbbbbbbbaabbbbbbbbbbaabbbbbbbbbbaabbbaaaabbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_p1":[7,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbbabbabbbaabbbbbbbbbbaabbbbbbbbbbaabbbbbbbabbaabbbbaaabbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_p2":[8,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbbabbabbbaabbbbbbbbbbaabbbbbbbbbbaabbabbbbabbaabbbaaaabbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_p3":[9,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbbabbabbbaabbbabbabbbaabbbbbbbbbbaabbbbbbbbbbaabbaaaaaabbaabbbaaaabbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "face_p4":[10,7,2,2,12,12,1,"#000000,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbaabbaabbaabbabbbbabbaabbbbbbbbbbaabbbbbbbbbbaabbaaaaaabbaabbaaaaaabba.abbaaaabba...abbbbbba.....aaaaaa..."],
    "face_p5":[11,7,2,2,12,12,1,"#000000,#ffffff,#000001","...aaaaaa.....abbbbbba...abbbbbbbba.abbcbbbbabbaabbbabbabbbaabbabbbbabbaabbbbbbbbbbaabbaaaaaabbaabbaaaaaabba.abbaaaabba...abbbbbba.....aaaaaa..."],
    "base_plan":[0,9,4,4,8,8,1,"#ffffff","aaaaaaaaa......aa......aa......aa......aa......aa......aaaaaaaaa"],
    "limits":[2,9,2,1,12,14,1,"#ffffff,#dadada",".....ab.........aaab.......aaaaab.....aaaaaaab...aaaaaaaaab.aaaaaaaaaaabbbbaaaaabbb....baaaab.......bab........ab..........aabaab......aaaaab......aaaaab......aaaaab..."],
    "seats":[3,9,2,2,12,11,1,"#ffffff,#dadada","....aaab.......aaaaab......aaaaab......aaaaab.......aaab..................aaaaaaab...aaaaaaaaab.aaaaaaaaaaabaaaaaaaaaaabaaaaaaaaaaab"],
    "limit_contracts":[4,9,4,2,9,10,1,"#dadada,#ffffff",".aaaaaaaabbbbbbbbab......bab.bbbb.bab......bab.bbbb.bab......bab.bbb..bab......babbbbbbbb."],
    "insights":[5,9,2,4,12,8,1,"#ffffff,#dadada","....aaaa......aa....aa...a...aa...a.a...abba...aa...abba...a.a...aa...a...aa....aa......aaaa...."],
    "coaching":[7,9,3,0,10,15,1,"#ffffff,#dadada","..a........aaa......aaaaa.....baaaaa....abaaaab...abbaabbb...abbabbaa..abbbaaaa..abbbaaaaaabbbbaaaaaabbbbaaaaaabbbbbaaaaabbbbbaaaa.abbbaaaa...aaa....."],
    "pip_plan":[8,9,3,2,10,11,1,"#ffffff,#dadada,#feffff","...aaab...aaaaaaaaaba.......aba.......aba.......aba.a..aa.abaaaaaaaacbaaaaaaaaabaaaaaaaaabaaaaaaaaabaaaaaaaaab"],
    "combat_pip":[9,9,2,2,12,12,1,"#dadada,#ffffff","..........ab.........aba........aba........aba....b...aba.....ab.aba.......bbba........bab........bbbbb......bba.aab....bba....a....ba.........."],
    "skill_pip":[10,9,1,1,14,14,1,"#ffffff,#dadada","......ab............ab...........aabb..........aabb.........aaabbb....aaaaaaabbaaaaa.baaaaabaaaab...bbbbabbbbb.....bbbabbbb......aaaabbbb......aaabbbbb.....aabb..bbbb...aabb....bbbb..ab........bb."],
    "magic_pip":[11,9,1,1,14,13,1,"#ffffff,#dadada","..........a........a...............b..b.a.....a...bb..........bbbb...........ab.b..a......b.b..........a.....a......b............a............b............a............b............."],
    "testing":[0,10,2,2,12,11,1,"#ffffff,#dadada","....aaaa.........aa..........aa..........aa.........a..a.......a....a.....abbbbbba...abaaaaaaba.abaaaaaaaabaabbbbbbbbbba.aaaaaaaaaa."],
    "aptitude":[1,10,2,1,12,14,1,"#ffffff,#dadada","...aaaaaa.....a......a...a...bb...a.a...b..b...aa...b..b...aa..bb..bb..a.a...bb...a..a..b..b..a...aa.bb.aa......bbbb.........aab........bbb..........aab........bbb....."],
    "brawn":[2,10,2,1,12,14,1,"#ffffff,#dadada","..aa.aa.......aa.aa.aa....aa.aa.aa.ab.aa.aa.aa.ab.bb.bb.bb.aab..b..b...baabbabbabbb..aaaaaaaaaab..aaaaaaaaaa...baaaaaab.....bbaaab......aaaaaa......aaaaaa......aaaaaa.."],
    "readiness":[3,10,4,2,8,13,1,"#ffffff,#dadada,#dadbda","....aaab...aaaab..aaaab..aaaab..aaaab...aaab....aaaaaaab.aaaaaab..aaaab..aaacb..aaab....aab.....ab......"],
    "personality":[4,10,2,2,12,12,1,"#dadada,#ffffff","...aaaaaa.....abbbbbba...abbbbbbbba.abbaabbaabbaabbaabbaabbaabbbbbbbbbbaabbbbbbbbbbaabbbaaaabbbaabbbbbbbbbba.abbbbbbbba...abbbbbba.....aaaaaa..."],
    "skill_test":[5,10,2,2,12,11,1,"#ffffff,#dadada",".........aa.........a..a.......a..a.......a..a.......a..a.......a..a.......ab.a.......abba.......abba.......abba.........aa........."],
    "education":[6,10,2,3,12,9,1,"#ffffff,#dadada",".aaaa..aaaa.a....aa....aa.bb.aa.bb.aa....aa....aa.bb.aa.bb.aa....aa....aa.bb.aa.bb.aa....aa....a.aaaa..aaaa."],
    "less_legal":[8,10,2,5,12,8,1,"#ffffff,#dadada",".aaaaaaaaaa.aaaaaaaaaaaaaabbaaaabbaaab..baab..baaa..aaaa..aaaaaaaaaaaaaabaaaabbaaaab.bbbb..bbbb."],
    "discrimination":[9,10,1,1,14,14,1,"#dadada,#ffffff","...aaaaaaaa.....abbbbbbbba...abaabbbbbbba.abab.abbabbabaabb..bbbbaabbaabbbbaabbbbbbaabbbbababb.bbaabb..aba..bbbaabbbbabaabbbbaabbbbabbbabbbaabbbbabbbbabba.abbbabbbbaba...abbabb.baa.....aa.bb.b...."],
    "odd_jobs":[10,10,1,1,14,14,1,"#ffffff,#dadada","....aa...aa........aaaaa..........bbb.........aaaaaaa......aaaabaaaa....aaaaabaaaa...aaaababbaaaa..aaaabbbabaaa.aaaaabababaaaaaaaaabababaaaaaaaaabababaaaabaaaabababaaab.bbaaaabaaaab....bbbbbbbbb.."],
    "who_knows":[11,10,1,1,14,15,1,"#ffffff,#dadada","...aaaaaaaa...aaaaaaaaaaaaaa..bbbbbbbbbb...bbb.bbbb.bbb...bb..bb..bb...b.bbb..bbb.b..bb........bb..bbbbbbbbbbbb..bbaaaaaaaaab..babbaaaabbab...baabaaaaab.....baaaaaab.......baaaab.........baab...........bb......"],
    "scroll":[13,10,2,1,12,14,1,"#ffffff,#dadada",".aaaaaaaaaa.abbbbbbbbbbaabbbbbbbbbba.aaaaaaaaaa...abbbbbba....ab....ba....abbbbbba....ab....ba....abbbbbba....ab....ba...aaaaaaaaaa.abbbbbbbbbbaabbbbbbbbbba.aaaaaaaaaa."],
    "magnifier":[0,11,1,1,14,14,1,"#ffffff,#dadada","..aaaaaa.......aa...baa.....aabbbb.baa....abbbbb.bba....abbb..bbba....abbb.bbbba....abbb.bbbba....aabbbbbbaa.....aab.bbaaa......aaaaaaaaa............aaa............aaa............aaa............aa"],
    "criminal":[1,11,2,1,12,14,1,"#dadada,#ffffff","aaaaaaaaaaaabbbbbbbbbbbbaaaaababababbbbbbbabababa..a.b.b.b.ba..a.b.b.b.bbbbbbbababbba..a.b.b.baba..a.b.b.bbbbbbbbbabababa..a.b.b.b.ba..a.b.b.b.baaaaabbbbbbbaaaaaaaaaaaa"],
    "survey":[2,11,3,2,10,11,1,"#ffffff,#dadada","..aaaaaa..aabbaabbaaabbbbbbbbaabaabaaabaabbbbbbbbaabababaabaabbbbbbbbaabaaaababaabbbbbbbbaabaaabaabaaaaaaaaaaa"],
    "peer":[3,11,2,2,12,11,1,"#ffffff,#dadada",".aaa....aaa.abbba..abbbaabbba..abbbaabbba..abbba.aaa....aaa..............aaaaaaaaaa.abbbbbbbbbbaab...bb...baabbbbbbbbbbaaaaaaaaaaaaa"],
    "customer":[4,11,2,2,12,11,1,"#ffffff,#dadada","....aaab.......abbbab......abbbab......abbbab.......aaab.................aaaaaaaaab.abbbbbbbbbabab.b...b.bababbbbbbbbbabaaaaaaaaaaab"],
    "chart_arrow":[5,11,1,1,14,14,1,"#dadada,#ffffff","a........bbbbba..........bbba.........bbbba........bbb.ba...bb...bb..ba..bbbb.bb....a.bb.bbbbb.aa.abb...bbb..aa.ab.........aa.a.......aa.aa.a....aa.aa.aa.a.aa.aa.aa.aa.a.aa.aa.aa.aa.aaaaaaaaaaaaaa"],
    "contract_metrics":[6,11,3,3,10,9,1,"#ffffff,#dadada,#dbdada","aaaaaaaa..abbbbbba..ab....babbabbbbbba.bab...bca.babbbbbba.baaaaaaaa.b..b......b..bbbbbbbb"],
    "merc_metrics":[7,11,2,1,12,13,1,"#ffffff,#dadada",".....aa.........abba........abba.........aa....................aaaaaa.....abbbbbba..............b.........a.b.a.......a.b.a.a...a.a.b.a.a.a.a.a.bbbbbbbbbbbb"],
    "bazaar_cat":[9,11,1,1,14,14,1,"#dadada,#ffffff","aabbaabbaabbaaaabbaabbaabbaaaabbaabbaabbaa...............b..........b..b..........b..b..........b..baaaaaaaaaab..baaaaaaaaaab.bbbbbbbbbbbbbbbaaaaaaaaaaaabba..aa..aa..abba..aa..aa..abbbbbbbbbbbbbbb"],
    "bazaar_node":[10,11,1,2,14,12,1,"#dadada,#ffffff","...aaaaaaaa.....ab...bbbba...ab...bbbbbba.aaabbbaaaaaaaaabb...bbbbbbbaabb...bbbbbbbaabb...bbbbbbbaabb...bbbbbbbaabbb..bbbbbbbaabbbb.bbbbbbbaabbbbbbbbbbbbaaaaaaaaaaaaaaa"],
    "better_items":[11,11,0,1,16,14,1,"#ffffff,#dadada",".....a....a.....a....a....a....a.a............a.....aaaaaaaa.......a.bbbbbb.a.....a.b.b..b.b.a...aaaaaaaaaaaaaa..abaabaaabaaaaa...ab..b...b..a.....ab..b...ba.......ab..b..a.........ab..ba...........ab.a.............aa......."],
    "faster_items":[12,11,2,5,12,7,1,"#dadada,#ffffff","aaa.aaaaaaaa....a..aaaaa.aa.bbbbbbbb....b..bbbbb..a.b..bbbbb....bb.bbbbb....bbbbbbbb"],
    "legal_cat":[0,12,1,2,14,12,1,"#ffffff,#dadada","....aaaaaa.......aaaaaaaa.....aaaaaaaaaa...bbbbbbbbbbbb..aaaaaaaaaaaa..a.a.a..a.a.a..a.a.a..a.a.a..a.a.abba.a.a..a.a.abba.a.a..a.a.abba.a.a..bbbbbbbbbbbb.aaaaaaaaaaaaaa"],
    "ops_permit":[1,12,3,3,9,10,1,"#ffffff,#dadada","aaaaaaaa.a......a.a.bbbb.a.a......a.a.bbb..a.a......a.a.bb.aaaaa....a..aaaaaaa..a.....aaaa"],
    "teleport":[2,12,2,2,12,12,1,"#ffffff,#dadada","....aaaa......aabbbbab...abbaaaabbb.abbabbbbabbaababbabbbabaabababbbbabaabababbababaabbbbaabbabaabbbbbbbabba.abbaaaabba...aabbbbaa......aaaa...."],
    "representation":[3,12,1,2,14,12,1,"#ffffff,#dadada",".....aaaa.........a....a....aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..aaaaaaaaaaaa..aaaaaa.aaaaaaaaaaaa..a..aaaaaa..a..abb......bba..abbbbbbbbbba..a.bbbbbbbb.a..aaaaaaaaaaaa."],
    "counsel":[4,12,1,2,14,11,1,"#ffffff,#dadada","......aa...aa.......aa.aa.b......aaaa..b.....aa.aa....b..aa...aa...aaa.b....aa....a...b...aa.......b....aa......aaa...aa.......a...bbbb.........aaaaaa...."],
    "promo_cat":[6,12,1,0,14,15,1,"#dadada,#ffffff","......a..............a..a..........a.a.........bb.....a......b.b...a.......b..b..........b...b.aa....bb.b...b..a...b...bbbb.....b...b........b...bb.......b...a.........a..a.a.........ab.a.a............aa......."],
    "promo_node":[7,12,4,3,8,10,1,"#ffffff,#dadada","aaaaaaaaaaabbaaaaaaaaaaaabbbbbbaaaaaaaaaabbbabbaaaaaabbaabbbabbaaaaaaaaaaaaaaaaa"],
    "promo_methods":[8,12,3,0,10,15,1,"#dadada,#ffffff","...a..a.......bb........bb.......a..a....b..bb..b.b.b.bb.b.bb..b..b..bb...bb...b.b..bb..b....bbbb......b..b......b..b.....b....b....bbbbbb...b......b."],
    "long_promos":[9,12,3,2,10,12,1,"#ffffff,#dadada","aaaaaaaaaa.a......a..a......a...a....a.....a..a.......aa........aa.......a..a.....a.bb.a...a.bbbb.a..abbbbbba.aaaaaaaaaa"],
    "guild_promo":[10,12,3,2,12,13,1,"#ffffff,#dadada","aaaaaaaaaa..aaaaaaaaaa..aabbbbbbaa..aab....baa..aab....baa..aabbbbbbaa..aaaaaaaaaa..aaaaaaaaaa..aaaa..aaabb.aaa....abbbbaaa....abbbbaa......abb.a........a.."],
    "marketing":[11,12,1,1,14,15,1,"#dadada,#ffffff",".aaaaaaaaaaaa..abbbbbbbbbba..ab...bb...ba..ab...bbbbbba..ab...bb..bba..abbbbbbbbbba..ab...bb...ba.aaaaaaaaaaaaaa.a.a.abba.......a..abba......a.a.abba.......a..abba......a.a.abba.......a..abba......a.a.abba....."],
    "star_set":[0,13,0,0,16,16,1,"#000000,#ffffff,#dadada,#f0efee",".......aa.............abca............abca...........abbcca..........abbcca......aaaabbbcccaaaa.adddddbbccddddda.acddddbcddddca...accccbdcccca.....accdbdbcca......abbbbdddda......abbbdcddda.....abbddaaccdda...abbdda..accdda..abdaa....aacda..aaa........aaa."],
    "star_unused":[1,13,1,1,14,14,1,"#ffffff,#dadada,#f0efee,#feffff","......ab............ab...........aabb..........aabb.........aaabbb....cccccaabbccccc.bccccabccccb...bbbbacbbbb.....bbcacabb......aadacccc......aaacbccc.....aacc..bbcc...aacc....bbcc..ac........bc."],
    "star9":[2,13,3,3,9,9,1,"#ffffff,#fffffe","....a.......aaa......aba...aaaaaaaaa.aaaaaaa...aaaaa....aaaaa...aaa.aaa..aa...aa."],
    "star7":[3,13,4,4,7,7,1,"#ffffff","...a.....aaa..aaaaaaa.aaaaa...aaa...aa.aa.aa...aa"],
    "sigil_divine":[0,14,0,1,15,15,0,"#f2a83d,#ffe45c,#fffbe6,#ffe55c,#d8e4f8,#d8e5f8,#fefbe6,#8a9cc0,#8b9cc0,#4a5a80,#8a9dc0,#ffe45d,#d8e4f9,#4a5a81,#4b5a80,#f2b33d",".......a..........a...b...a.......b.aba.b.........abcba.........adcccba..e..f..bcgcccb.eh..he.abcccba.ije..ke.abcla.ehhj...hhembeefhijj..nhhhhhhhkhhj..hhjjjjjjojj...pppi...........hehk...........ehh............kk............."],
    "sigil_mage":[1,14,0,0,16,16,0,"#d8b160,#d9b060,#d8b060,#e8f0ff,#8ab0ff,#4a6ae0,#c8d8ff,#5a80d8,#2a3a90,#2b3a90,#2a3a91,#4a6ae1,#2a3b90,#8ab0fe","....ab...........cc..de...ccc...c..c.eec.c...c..c.c.c.c.c..c..c..c.fff..c.c.ade...fgfff..c..ceeh..fgffi......ch..cfffii......ff.c..jii......fgfk.c....cc....ffii.lf.....fff.ciicfgfi...fgfffc.c.ffii...fgffi.de..ii.c..fffmi.eeh.dec.c..iii.c.h..nec..c..c......"],
    "sigil_mystech":[2,14,0,0,16,16,0,"#2f8a6c,#3df08a,#c9b040,#c8b040,#3df18a,#28b870,#e0fef0,#e0fff0,#3df08b,#28b871,#29b870,#2e8a6c,#e0fff1,#3cf08a,#e1fff0,#2f8b6c,#c8b140","......aaaa............bcdb.........abe.f..bba.....ab.g.f.h..ba....b..f.f.f.h.e....i.h.jk.ff..i..ab..f.bbbb.fh.baadfjffbghb....daldf...bhmbffffdaab.f..bbnb.f..ia..i.f.f.f..h.b....b..of.j....b....ab..h.f...bp.....abb..f.bna.........bqdb............aaaa......"],
    "sigil_performer":[3,14,0,0,16,16,0,"#3df06a,#3cf06a,#3df06b,#f07ab8,#b04a80,#b14a80,#f3ead7,#f17ab8,#f07bb8,#9ad8ff,#3aa860,#ff9ad0,#f3ead6",".a..b......a..a..bc.a.a..a.a.aa...aaaa....baaa......dddddddd.......ddeddddfdd......dd.ddd..dd....ggd.d.ddhd.d....g.dd.ddddijd...gg.ed.klkkhjd...gg..eilklkkgggg......fllkkeg..g.....lgglkkggk.g....llmlllkggk.g..lllmgllkkkkkgg.l.llgg.kk.kkkggkl.ll..k...kkk..k"],
    "sigil_sorcerer":[4,14,1,0,14,16,0,"#f0a8ff,#f0884a,#c040f1,#8a2ab0,#c86a30,#a85020,#c041f0,#c040f0,#f0a8fe,#a95020,#f0884b,#c86b30,#a85021,#c96a30,#f0894a,#c86a31","......ab...cd......eabf.gdhd..cdebabbf..hd.hdhebibbj.hhd.hd.ebab.fhhd..hcdebab.hhd....ghebabbfd......hh.abkf........lbabbf........ebab.md.......ebab.chd...hd.nbabbfhhd.hd.hh.abof.hhdhdhhdebbj...hddchd..pf..cdhd.dd........hd."],
    "sigil_brave":[5,14,0,0,16,16,0,"#f2c33d,#3b6fd0,#f2c23d,#2b4f8a,#2b4e8a,#2b4f8b,#a87818,#3b6ed0,#a87918,#a97818,#2a4f8a,#c07820,#f3c23c","a.....bbbb.....c.c..bbddddbb..c...cbddddddedbc....bcedddddddcb...bddcdddfddcddb..bdddcggggcdddb.hddddgcggciddddbhddddggccjgdfddbbddedggccggdddkbbddddjcggcgfdddb.bkcdcgggicdcdb..bddlddddddlddb...bldcddddmdlb....lbddddddddbl...c..bbddddbb..c.......bbbb......"],
    "sigil_chymist":[6,14,0,0,16,16,0,"#a06a30,#f5c090,#f5c190,#3de08a,#3de18a,#5aa0a8,#5aa1a8,#2e6a70,#2e6b70,#f4c090,#f3ead7,#2e6a71,#b8ffd8,#3de08b","..a...bbcb.........ddddddebb......fgd....dddb.....fhh......ddb...b..hh......ddb..b...hhhhih.ddj.b.....hfhihh.d.bb....hfhkkkhhd.bb....hlkhkhkhd.bb....hhkkkkkhd.b.b...hddkdkdhdb..b....hdmddh.db...b....ihhldeb.....b.dddndddb.......bbd.d.bb..........bbbb......"],
    "sigil_hellion":[7,14,0,0,16,16,0,"#7a7090,#a89ec0,#d06a20,#c8c0dc,#a89ec1,#c8c0dd,#5a4889,#5a4888,#f3ead7,#e07a2a,#e17a2a,#7a68a8,#5a4988,#a04a14,#7a7091,#e88a3a,#e88b3a,#7a3410,#b05818,#7a7190","......abab..........abccdeab......da.c..c...ad....af.cc.ghh.da...b......hgijj.b..a.....hhjjj..a.b....hjjhkj....ead..hjjhhj.....ab..hhlghhj....dba.hhlhmhh.n....o.hh...h.h.n...b..ppqppppppnrnja...ssssssssnnrj....da......n.ad.....dtb.d..abd.........tdtd......"],
    "sigil_honorable":[8,14,0,0,16,16,0,"#9bd8ff,#9ad8ff,#2f9ee8,#9ad9ff,#e0501e,#f28c29,#ffc040,#f28c28,#f28d28,#fff0b0,#ffc140,#e0511e,#2f9ee9",".......ab........b.....cc.....b...c..d.cc.b..c.....c.b.cc.b.c.......c.efge.c......bb.ehghge.bb......egigjhke....accchggjgghecccbbcccehgjjghhcccb....ehggghge......bb.ehfghl.bd......c.eehe.c.......c.b.cc.b.c.....c..b.cc.b..c...b.....cm.....b........aa......."],
    "sigil_warrior":[9,14,0,0,16,16,0,"#f0c8e9,#f0c8e8,#f4e4f4,#f4e5f4,#8b5a48,#c8a8c8,#f1c9e8,#c9a8c8,#c8a9c8,#8a5a48,#f5e4f4,#c8a8c9,#9a5a90,#9a5b90,#9a5a91,#f1c8e8,#c898c0,#c898c1,#c998c0,#5e3458,#9b5a90,#5e3459,#c89071,#c89070,#c89170","......a..b.........cc.b..b.dc....e.ff.bbgb.hi.j...jf...bb...fj..kflj..mnmm..jffccf..jmmmmmoj..lc....mmmmmmmm....bb..mmmmmmmn..bb.pbbm..mm..mbbb..qrqmm.mm.mmsqs.qq..mmt..tmu..qq....mmt..vmm........jmt..tmj.......j..n..m..j.....w....bb....x...y....bbbb....x."],
    "face_unselected_o":[0,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a..aa..aa..aa..aa..aa..aa..........aa..........aa...aaaa...aa..........a.a........a...a......a.....aaaaaa..."],
    "face_m5_o":[1,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a..a....a..aa..aa..aa..aa..........aa..........aa...aaaa...aa..aaaaaa..a.a.a....a.a...a......a.....aaaaaa..."],
    "face_m4_o":[2,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a..a....a..aa...a..a...aa..........aa..........aa...aaaa...aa..a....a..a.a........a...a......a.....aaaaaa..."],
    "face_m3_o":[3,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a...a..a...aa...a..a...aa..........aa..........aa...aaaa...aa..a....a..a.a........a...a......a.....aaaaaa..."],
    "face_m2_o":[4,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a...a..a...aa..aa..aa..aa..........aa..........aa....aa....aa...a..a...a.a........a...a......a.....aaaaaa..."],
    "face_m1_o":[5,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a...a..a...aa..a....a..aa..........aa..........aa...aaa....aa..a.......a.a........a...a......a.....aaaaaa..."],
    "face_0_o":[6,8,2,2,12,12,1,"#ffffff,#fffeff","...aaaaaa.....a......a...a........a.a...a..a...aa...a..a...aa..........aa..........aa..........aa...abaa...a.a........a...a......a.....aaaaaa..."],
    "face_p1_o":[7,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a...a..a...aa...a..a...aa..........aa..........aa.......a..aa....aaa...a.a........a...a......a.....aaaaaa..."],
    "face_p2_o":[8,8,2,2,12,12,1,"#ffffff,#feffff","...aaaaaa.....a......a...a........a.a...a..a...aa...a..a...aa..........aa..........aa..a....a..aa...aaaa...a.a........a...a......a.....aaabaa..."],
    "face_p3_o":[9,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a...a..a...aa...a..a...aa..........aa..........aa..aaaaaa..aa...aaaa...a.a........a...a......a.....aaaaaa..."],
    "face_p4_o":[10,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a..aa..aa..aa..a....a..aa..........aa..........aa..aaaaaa..aa..aaaaaa..a.a..aaaa..a...a......a.....aaaaaa..."],
    "face_p5_o":[11,8,2,2,12,12,1,"#ffffff","...aaaaaa.....a......a...a........a.a..a....a..aa...a..a...aa..a....a..aa..........aa..aaaaaa..aa..aaaaaa..a.a..aaaa..a...a......a.....aaaaaa..."]};
  const K = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const cache = {};
  const rgb = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
  function cells(id, tint, force) {
    const e = D[id]; if (!e) return [];
    const key = id + '|' + (tint || '') + (force ? '!' : '');
    if (cache[key]) return cache[key];
    const pal = e[7].split(','), t = tint && (e[6] || force) ? rgb(tint) : null;
    const cols = pal.map(p => { if (!t) return p; let c = rgb(p); if (!e[6]) { const l = Math.round(0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]); c = [l, l, l]; } return '#' + c.map((v, i) => Math.round(v * t[i] / 255).toString(16).padStart(2, '0')).join(''); });
    return (cache[key] = e[8].split('').map(ch => ch === '.' ? 'transparent' : cols[K.indexOf(ch)]));
  }
  function cell16(id, tint, force) {
    const e = D[id]; if (!e) return [];
    const key = '16|' + id + '|' + (tint || '') + (force ? '!' : '');
    if (cache[key]) return cache[key];
    const src = cells(id, tint, force), out = Array(256).fill('transparent');
    for (let y = 0; y < e[5]; y++) for (let x = 0; x < e[4]; x++) out[(e[3] + y) * 16 + e[2] + x] = src[y * e[4] + x];
    return (cache[key] = out);
  }
  function box(id, x, y, w, h, tint, force) {
    const c = cell16(id, tint, force), out = [];
    for (let r = y; r < y + h; r++) for (let q = x; q < x + w; q++) out.push(c[r * 16 + q] || 'transparent');
    return out;
  }
  function solid(id, color) {
    const e = D[id]; if (!e) return [];
    return e[8].split('').map(ch => ch === '.' ? 'transparent' : color);
  }
  // Difficulty star, full 16×16 cell. fill 1 = star_set tinted color; 0 = star_unused tinted empty; 0.5 = left 8 columns set, right 8 unused.
  function diffStar(fill, color, empty) {
    const a = cell16('star_set', color, true), b = cell16('star_unused', empty || '#1f3560', true);
    return a.map((c, i) => fill >= 1 || (fill > 0 && i % 16 < 8) ? c : b[i]);
  }
  // Icon on an active (orange) tab: neutral light pixels -> brown body, saturated (orange/green…) and dark pixels -> near-black.
  function tabOn(id) {
    const key = 'on|' + id; if (cache[key]) return cache[key];
    return (cache[key] = cell16(id).map(c => {
      if (c === 'transparent') return c;
      const [r, g, b] = rgb(c), mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = 0.299 * r + 0.587 * g + 0.114 * b;
      if (mx - mn > 40 || l < 90) return '#0a0f1c';
      return l > 200 ? '#5a3510' : '#3a2008';
    }));
  }
  function mask(id, ch, darkCh) {
    const e = D[id]; if (!e) return [];
    const m = ch || '#', rows = [];
    const pal = e[7].split(','), dark = pal.map(p => { const c = rgb(p); return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] < 176; });
    for (let y = 0; y < e[5]; y++) rows.push(e[8].slice(y * e[4], (y + 1) * e[4]).split('').map(c => c === '.' ? '.' : darkCh && dark[K.indexOf(c)] ? darkCh : m).join(''));
    return rows;
  }

  // One-image pixel icons. [colors...].pxN → SVG data URL of the cell array laid out N columns wide
  // (1 unit per art pixel; scale with CSS width + image-rendering:pixelated). 'currentColor' cells draw white (use as a CSS mask).
  const urlCache = new Map();
  function pxUrl(arr, cols) {
    if (!arr || !arr.length) return '';
    const key = cols + '|' + arr.join(',');
    let u = urlCache.get(key); if (u) return u;
    const rows = Math.ceil(arr.length / cols), byCol = {};
    for (let i = 0; i < arr.length; i++) {
      let c = arr[i]; if (!c || c === 'transparent') continue; if (c === 'currentColor') c = '#ffffff';
      const x = i % cols, y = (i / cols) | 0;
      let run = 1; while (x + run < cols && arr[i + run] === arr[i]) run++;
      (byCol[c] = byCol[c] || []).push('M' + x + ' ' + y + 'h' + run + 'v1h-' + run + 'z');
      i += run - 1;
    }
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + cols + '" height="' + rows + '" viewBox="0 0 ' + cols + ' ' + rows + '" shape-rendering="crispEdges">' + Object.keys(byCol).map(c => '<path fill="' + c + '" d="' + byCol[c].join('') + '"/>').join('') + '</svg>';
    u = 'data:image/svg+xml,' + encodeURIComponent(svg);
    urlCache.set(key, u); return u;
  }
  for (let n = 1; n <= 32; n++) if (!Object.getOwnPropertyDescriptor(Array.prototype, 'px' + n)) Object.defineProperty(Array.prototype, 'px' + n, { get() { return pxUrl(this, n); }, configurable: true });
  window.MercIcons = { pxUrl, data: D, cells, cell16, box, solid, diffStar, tabOn, mask, w: id => (D[id] || [0, 0, 0, 0, 1])[4], h: id => (D[id] || [0, 0, 0, 0, 1, 1])[5],
    info: id => { const e = D[id]; return e && { cell: [e[0], e[1]], offset: [e[2], e[3]], size: [e[4], e[5]], mono: !!e[6] }; } };
})();
