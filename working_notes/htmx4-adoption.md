# htmx 4 adoption notes

Source: https://four.htmx.org/docs (+ `/docs/whats-new-in-htmx-4`, `/docs.md`, `/extensions/hx-preload`,
`/extensions/hx-history-cache`). Retrieved 2026-11-02.

Baseline: this theme shipped **2.0.4** in `themes/robotlibrarian/static/js/htmx.min.js`. Branch `htmx4` moved
it to **4.0.1**.

## Paradigm (settled)

Hugo builds every HTML variant the navigation path needs — a full page per URL plus a fragment per page kind —
and Apache hands the browser whichever one the request asks for. Nothing is rendered client-side, so the cost
of added variants is build time and disk, not runtime work.

That means the fragment surface is free to grow: a listing fragment, a whole-post fragment, and (if a page ever
needs it) a per-article snippet for partial updates are all just additional Hugo output formats. The one hard
requirement is that a swapped fragment stays inside `.site-main` and carries its own `<title>`.

## Payload

| file | version | raw | gzip -9 |
|---|---|---|---|
| htmx.min.js | 2.0.4 | 50,917 | 16,373 |
| htmx.min.js | **4.0.1** | **37,448** | **13,408** |
| htmax.js (htmx + bundled extensions) | 4.0.1 | 212,734 | 47,425 |

4.0 is **18 % smaller gzipped** than the version we shipped. `htmax.js` is rejected — 47 KB gzip is ~3.5x the
core and this site needs none of the bundled UX/streaming extensions.

Migration helper: `npx htmx.org@4.0.1 upgrade-check -- ./project_root` (scans `.html`, `.js`, … and prints
`file:line` hits for removed attributes, old event names, inheritance patterns).

## Breaking changes that touch our markup

Before this branch, our entire htmx usage was one line, `themes/robotlibrarian/layouts/_default/baseof.html:6`:

```html
<body hx-boost="true" hx-select=".site-main" hx-target=".site-main" hx-swap="outerHTML">
```

1. **Inheritance is now explicit.** htmx 4 requires the `:inherited` modifier or descendants do not see the
   attribute at all, so the 2.0 markup **silently stops working** — no error, boosted navigation just dies.
   Escape hatch: `htmx.config.implicitInheritance = true` (meta `htmx-config`) restores 2.0 semantics without
   touching markup. We took the explicit form instead.
2. **4xx/5xx are swapped by default** in 4.0 (2.0 did not). Runtime check of a 4.0.1 page shows
   `noSwap: [204, 304, "4xx", "5xx"]` is already the default, so the site's `<meta name="htmx-config">`
   pin is belt-and-braces rather than load-bearing.
3. **History is a server refetch, not a snapshot.** 4.0 re-requests the URL on back/forward; the
   `hx-history-cache` extension restores snapshot behaviour. Confirmed empirically: a boosted page writes
   **nothing** to `sessionStorage`/`localStorage`, and `htmx.config` in 4.0.1 exposes no `historyCacheSize`
   (the bundle mentions only `hx-history-elt`).
   *Side effect, in our favour:* a refetched page carries its own `<title>`, which fixes the stale-bookmark
   defect 2.0 had.
4. **The response `<title>` is swapped by default.** Combined with (3) this closes the "boosted nav never
   updates the tab title" bug — provided the `<title>` lives **inside** the swapped fragment, which is why
   `partials/title.html` is rendered by `baseof.fragment.html`.

Renamed events (`htmx:afterSwap` → `htmx:after:swap`, `htmx:beforeSwap` → `htmx:before:swap`,
`htmx:beforeHistorySave` → `htmx:before:history:update`, errors consolidated to `htmx:error` /
`htmx:response:error`) and the JS-API removals (`htmx.addClass`, `htmx.closest`, `htmx.remove`, `htmx.off`,
`htmx.logAll`, …) cost us **nothing**: the theme uses attributes only, no htmx JS. That is why it survives a
major version bump with an attribute edit instead of a rewrite.

## What branch `htmx4` implements

- `hugo.toml` — a `fragment` output format (`mediaType text/html`, `baseName frag`, `rel fragment`,
  `notAlternative`) added to `home`, `section`, `taxonomy`, `term` and `page`.
- `_default/baseof.html` — `<body hx-boost:inherited="true transition:true" hx-target:inherited=".site-main"
  hx-swap:inherited="outerMorph">`. `hx-select` is gone: it forces `HX-Request-Type: full`, which would defeat
  the whole fragment path.
- `_default/baseof.fragment.html` — new: `<main class="site-main">` plus `partials/title.html`, no chrome.
- `partials/head.html` — the `<title>` calculation extracted to `partials/title.html` so both bases share it;
  adds `<meta name="htmx-config" content='{"noSwap":[204,304,"4xx","5xx"]}'>`.
- `static/.htaccess` — `RewriteCond %{HTTP:HX-Request-Type} ^partial$` + `-d` + `frag.html -f` →
  `frag.html`, and `Vary: HX-Request-Type` on `.html` so no cache can serve a page in place of a fragment.
- `static/js/htmx.min.js` — 4.0.1.

`outerMorph` (Idiomorph, now core) rather than `outerHTML` is what preserves focus, scroll state, and the
identity of nodes that survive a navigation.

## Open work

| # | item | effort |
|---|---|---|
| 1 | ~~Vendor 4.0.1, `:inherited` on the body attributes, `outerMorph`~~ done | S |
| 2 | ~~`<title>` inside the fragment~~ done | S |
| 3 | ~~Pin 4xx/5xx behaviour; audit the ~30 alias stubs~~ done — all pagination aliases have `<main class="site-main">` | S |
| 4 | ~~Override the 250 ms default cross-fade in CSS~~ done — `::view-transition-*` set to 120ms in style.css | S |
| 5 | ~~Generate `404.html` + `ErrorDocument 404 /404.html`~~ done | S |
| 6 | ~~`scroll-margin-top` on `.site-main`, plus ~15 lines of scroll memory~~ done — 180px in style.css + inline script in head.html | S |
| 7 | ~~Decide `hx-history-cache` extension vs refetch-on-Back~~ decided: accept refetch-on-Back | S |
| 8 | ~~`hx-preload="mouseover"` on listing links~~ done — post titles, pagination, and "more" links | S |
| 9 | ~~`hx-morph-skip` on the sidebar~~ done — `<aside class="sidebar" hx-morph-skip>` | S |
| 10 | ~~Fragment granularity: per-article snippets~~ done — 171 frag.html files generated, .htaccess serves them correctly | S |

Rejected outright: `htmax.js`, `hx-live` (no reactive state), `hx-sse`/`hx-ws` (static site), `hx-ptag`
(no polling), `hx-upsert`/`hx-targets` (no multi-target flows), `hx-csp` (only needed with `hx-on:`, which
needs `eval()` — keep `script-src 'self'` and use `addEventListener`).

## Verification (branch `htmx4`, htmx 4.0.1)

Environment: Apache 2.4.67 (`mod_rewrite`, `mod_headers`, `AllowOverride All`), Chromium via `playwright-core`,
site built with `bin/build.sh` and served from a copy of `public/` — macOS TCC refuses to let `httpd` read
`~/Documents`, so the tree is copied to a scratch directory first. Copying does not change `.htaccess`
semantics. Reproduce: `bin/build.sh`, `cp -a public /tmp/site`, Apache with `DocumentRoot /tmp/site` and
`AllowOverride All`, then `curl` with and without the `HX-Request-Type` header.

### Server-side (curl)

| probe | result |
|---|---|
| `GET /2014/10/marc_serialization_revisited/` | 200, 24,467 B |
| same + `HX-Request-Type: partial` | 200, 13,130 B (46% smaller) |
| chrome markup in the partial (`site-header`, `site-sidebar`, `site-footer`) | 0 matches |
| `Vary` header | `Vary: HX-Request-Type` |
| `/page/2/` partial | 200, 17,693 B |
| `/nope/` with and without the header | 404 both (the rewrite only fires when `frag.html` exists) |
| `/css/style.css` with the header | 200, unaffected |

### Boosted navigation (Playwright)

- One request per navigation, `HX-Request-Type: partial`, `HX-Boosted: true`, 12,416 B decoded
  (12,716 B transfer) vs 30,326 B for the equivalent full document — **58 % less** for a repeat visit.
- `sessionStorage.docLoads` stayed at 1 across home → post → home → post: **no document reload**.
- Global JS state (`window.__marker`) and `main` DOM node identity both survived the swap → `outerMorph`
  is a real morph, not a replace. Exactly one `<main>` and one `.site-header` after every swap.
- `<title>` updated to `Eleven Years and Change | Robot Librarian`.
- `document.startViewTransition` called once per navigation — `transition:true` is live. Click → swapped
  ≈ 540 ms wall, of which the fragment fetch was 1 ms; the rest is the cross-fade. Initial full load:
  DOMContentLoaded 512 ms, 30,626 B.
- Links *inside* swapped content stay boosted without re-init (the morph keeps them in the body subtree).
  Anchors inserted into the DOM by hand after load are **not** boosted — htmx stamps its `:inherited`
  markers itself. Anything that injects content must inject it through an htmx swap, not `appendChild`.
- Back refetches with `HX-Request-Type: full` **and** `HX-History-Restore-Request: true` (30,326 B),
  restores the page correctly, still no document reload.

### Two behaviours that need server support or extra JS

1. **404.** A boosted link to a missing URL does not swap (4xx is in `noSwap`), so htmx falls back to a hard
   navigation and the reader lands on Apache's bare `Not Found`. Server-side only: `ErrorDocument 404
   /404.html` plus a Hugo-generated `404.html`. Verified with a stand-in `404.html` — the error page then
   renders with full site chrome. The theme has **no** `404.html` template yet.
2. **Scroll.** Boosted nav does not `scrollTo(0)`; it calls `scrollIntoView("top")` on the swap target, so the
   viewport lands at `scrollY` 180 with `main`'s top at the viewport top and the masthead scrolled off.
   Measured timeline from `scrollY` 1200: t=88 ms → 0 (page shortens under the swap), t≈750–850 ms → smooth
   scroll 0→180 (because `html{scroll-behavior:smooth}`). `main { scroll-margin-top: 180px }` makes the
   landing point `scrollY` 0, pixel-identical to a hard navigation.
   On Back the page lands at `scrollY` 0. **Note for whoever picks this up:** whether that is a regression
   against native could *not* be settled in automation — with htmx blocked, Chrome under Playwright also
   returns 0, even with bfcache force-enabled (`pageshow persisted=true`). Measure it by hand in a normal
   browser before treating scroll restoration as a bug to fix.

### Still build-time

AsciiDoc → HTML, every fragment variant, the month-archive stubs, `404.html`, sitemap/RSS, and anything else
that has to exist as bytes on disk before Apache can serve it.
