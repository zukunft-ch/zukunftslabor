// Render Vega-Lite specs to static SVG fallbacks with the site's light theme (Alpenglühen).
import fs from 'fs'; import path from 'path';
import * as vega from 'vega'; import * as vl from 'vega-lite';
const dir = process.argv[2];
const config = {
  background: 'transparent', font: 'Switzer, system-ui, sans-serif',
  axis: { labelLimit: 280, labelColor: '#4f565b', titleColor: '#121517', gridColor: 'rgba(18,21,23,0.08)', domainColor: 'rgba(0,0,0,0.08)' },
  legend: { labelColor: '#4f565b', titleColor: '#121517' }, title: { color: '#121517' }, view: { stroke: 'transparent' },
  range: { category: ['#c026d3', '#6d28d9', '#f43f5e', '#4338ca', '#64748b', '#d97706'], ramp: ['#ede9fe', '#6d28d9'] },
  mark: { color: '#6d28d9' }, bar: { color: '#6d28d9' }, line: { color: '#c026d3', strokeWidth: 2.5 }, point: { color: '#c026d3' },
  area: { color: '#6d28d9', opacity: 0.85 }, rule: { color: '#64748b' }
};
vega.formatLocale({ decimal: '.', thousands: "'", grouping: [3], currency: ['CHF ', ''] });
const files = process.argv.slice(3).length ? process.argv.slice(3) : fs.readdirSync(dir).filter(f => f.endsWith('.json'));
let ok = 0, bad = [];
for (const f of files) {
  try {
    const spec = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    if (!spec.width || spec.width === 'container') spec.width = 680;
    spec.config = { ...(spec.config || {}), ...config, axis: { ...(spec.config?.axis || {}), ...config.axis } };
    const vg = vl.compile(spec).spec;
    const view = new vega.View(vega.parse(vg), { renderer: 'none' });
    const svg = await view.toSVG();
    fs.writeFileSync(path.join(dir, f.replace(/\.json$/, '.svg')), svg);
    ok++;
  } catch (e) { bad.push(f + ': ' + e.message.slice(0, 80)); }
}
console.log('rendered', ok, 'failed', bad.length); bad.forEach(b => console.log('  ', b));
