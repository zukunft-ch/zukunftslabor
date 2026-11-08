// Render Vega-Lite specs to static SVG fallbacks (light + .dark.svg) with the SAME house style
// as the live charts: themes/avenir/static/js/dz-charts.js (DZCharts.config / DZCharts.prepare).
// Usage: node render_charts.mjs <charts-dir> <path/to/dz-charts.js> [spec.json ...]
// Lead figures (first chart of each note) are rendered taller; pass their names via LEAD=a,b,c.
import fs from 'fs'; import path from 'path'; import vm from 'vm';
import * as vega from 'vega'; import * as vl from 'vega-lite';
const [dir, dzPath, ...only] = process.argv.slice(2);
vm.runInThisContext(fs.readFileSync(dzPath, 'utf8'));
const DZ = globalThis.DZCharts;
const lead = new Set((process.env.LEAD || '').split(',').filter(Boolean));
vega.formatLocale({ decimal: '.', thousands: "'", grouping: [3], currency: ['CHF ', ''] });
const files = only.length ? only : fs.readdirSync(dir).filter(f => f.endsWith('.json'));
let ok = 0, bad = [];
for (const f of files) {
  const name = f.replace(/\.json$/, '');
  for (const dark of [false, true]) {
    try {
      const raw = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
      const { spec } = DZ.prepare(raw, { dark, lead: lead.has(name), width: 1000 });
      spec.width = 1000 - 40; spec.autosize = { type: 'fit-x', contains: 'padding' };
      spec.config = DZ.config(dark);
      const vg = vl.compile(spec).spec;
      vg.width = 1000; 
      const view = new vega.View(vega.parse(vg), { renderer: 'none' });
      const svg = await view.toSVG();
      fs.writeFileSync(path.join(dir, name + (dark ? '.dark.svg' : '.svg')), svg);
      if (!dark) ok++;
    } catch (e) { bad.push(f + (dark ? ' (dark)' : '') + ': ' + e.message.slice(0, 100)); }
  }
}
console.log('rendered', ok, 'failed', bad.length); bad.forEach(b => console.log('  ', b));
