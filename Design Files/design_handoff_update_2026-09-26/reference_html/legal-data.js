// PLACEHOLDER legal seed shared by Game HUD (notification dot) and Legal. LegalManager autoload in Godot.
window.mercLegalSeed = () => ({
  today: 540,
  permits: { 0: { ops: true }, 2: { ops: true, tele: true } },
  fines: [
    { id: 1, loc: 2, crime: 'Crime 1', mercs: [3, 6], contract: 11, issued: 530, due: 548, amount: 180, unread: true },
    { id: 2, loc: 0, crime: 'Crime 2', mercs: [1], contract: 12, issued: 520, due: 535, amount: 450, unread: false },
    { id: 3, loc: 3, crime: 'Crime 3', mercs: [2, 7, 8], contract: 13, issued: 538, due: 561, amount: 900, unread: true },
    { id: 4, loc: 0, crime: 'Crime 4', mercs: [5], contract: 11, issued: 500, due: 520, amount: 60, paid: 60, paidDay: 517 }],
  captured: [
    { id: 1, merc: 4, loc: 3, crime: 'Crime 5', contract: 13, since: 536, sentence: 30, bail: 350, unread: true },
    { id: 2, merc: 9, loc: 2, crime: 'Crime 6', contract: 11, since: 530, sentence: 20, bail: 220, unread: false }],
  jobs: {},
});
