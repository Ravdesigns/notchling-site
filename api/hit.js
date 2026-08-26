// Notchling's own counter. No third-party analytics, no cookies, no identifiers —
// three tallies and a referring hostname.
//
// POST /api/hit?e=visit|download|install[&r=referrer]  → record one event
// GET  /api/hit                                        → totals, referrers, by-day
//
// Storage is APPEND-ONLY: one empty blob per event, named
//   notchling/ev/<YYYY-MM-DD>/<event>/<host>/<random>
// and totals are computed by listing that prefix.
//
// It started as a single JSON counter doing read-modify-write, the same pattern as
// the other toys. That silently LOST events: Vercel Blob is eventually consistent
// on overwrite, so five posts a second apart counted as one, and a POST could
// report 4 while the next GET still said 3. Appending never reads before it
// writes, so nothing can race and nothing is lost.
//
// `install` is the tally that matters most: the curl one-liner never loads the
// page, so no JavaScript analytics product can see it at all.
import { put, list } from '@vercel/blob';

const ROOT = 'notchling/ev';
const EVENTS = ['visit', 'download', 'install'];

// Coarse hostname only — never a full URL or query string, which can carry
// personal data we have no business storing.
function refHost(raw) {
  if (!raw) return 'direct';
  try {
    const h = new URL(raw.startsWith('http') ? raw : `https://${raw}`)
      .hostname.replace(/^www\./, '').toLowerCase();
    return (h.replace(/[^a-z0-9.-]/g, '').slice(0, 60)) || 'direct';
  } catch { return 'other'; }
}

async function tally() {
  const out = { visits: 0, downloads: 0, installs: 0, refs: {}, days: {} };
  let cursor;
  do {
    const page = await list({ prefix: `${ROOT}/`, limit: 1000, cursor });
    for (const b of page.blobs) {
      // notchling/ev/<date>/<event>/<host>/<random>
      const p = b.pathname.split('/');
      if (p.length < 6) continue;
      const [, , date, event, host] = p;
      if (!EVENTS.includes(event)) continue;
      const key = event === 'visit' ? 'visits' : event === 'download' ? 'downloads' : 'installs';
      out[key]++;
      out.days[date] = out.days[date] || { visits: 0, downloads: 0, installs: 0 };
      out.days[date][key]++;
      if (event === 'visit') out.refs[host] = (out.refs[host] || 0) + 1;
    }
    cursor = page.hasMore ? page.cursor : undefined;
  } while (cursor);
  return out;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();

  try {
    if (req.method !== 'POST') {
      res.setHeader('Cache-Control', 'no-store');
      return res.status(200).json({ ok: true, ...(await tally()) });
    }

    const e = String(req.query.e || '');
    if (!EVENTS.includes(e)) return res.status(400).json({ ok: false, error: 'unknown event' });

    const date = new Date().toISOString().slice(0, 10);
    const host = e === 'visit' ? refHost(req.query.r || req.headers.referer) : '_';
    const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`;

    await put(`${ROOT}/${date}/${e}/${host}/${id}`, '1', {
      access: 'public', addRandomSuffix: false, contentType: 'text/plain',
      cacheControlMaxAge: 31536000,   // the blob never changes; cache it forever
    });
    return res.status(200).json({ ok: true, recorded: e });
  } catch {
    // A broken counter must never break the page or the installer.
    return res.status(200).json({ ok: false });
  }
}
