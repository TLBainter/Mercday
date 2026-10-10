(function () {
  const AUDIO = /(sound|sfx|audio|music|\bost\b|\.ogg|\.wav|\.mp3|\.flac)/i;
  const SIZE_RX = /(?:^|[^0-9])(\d{2,3})\s*x\s*(\d{2,3})(?:[^0-9]|$)/i;
  function pick(items) {
    const ok = items.filter(i => !AUDIO.test(i.name));
    if (!ok.length) return [];
    const sized = ok.map(i => {
      const m = i.name.match(SIZE_RX);
      return { i, s: m ? parseInt(m[1], 10) : 0 };
    });
    const has32 = sized.filter(x => x.s === 32);
    if (has32.length) return has32.map(x => x.i);
    const withSize = sized.filter(x => x.s > 0);
    if (withSize.length) {
      const min = Math.min(...withSize.map(x => x.s));
      const smallest = withSize.filter(x => x.s === min).map(x => x.i);
      const unsized = sized.filter(x => x.s === 0).map(x => x.i);
      return smallest.length ? smallest.concat(unsized) : unsized;
    }
    return ok;
  }
  async function run() {
    for (let t = 0; t < 40 && !document.querySelector('.upload'); t++) await new Promise(r => setTimeout(r, 250));
    const items = [...document.querySelectorAll('.upload')].map(el => ({
      el,
      name: (el.querySelector('.name, strong.name') || el).textContent.trim(),
      btn: el.querySelector('.download_btn, a.button')
    })).filter(i => i.btn);
    const chosen = pick(items);
    console.log('[Itch Pack Grabber]', document.title, 'files:', items.map(i => i.name), 'chosen:', chosen.map(i => i.name));
    for (const c of chosen) {
      c.btn.click();
      await new Promise(r => setTimeout(r, 2500));
    }
  }
  run();
})();
