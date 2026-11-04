# Robot Librarian — Hugo

A static re-hosting of Bill Dueber's **Robot Librarian** blog
(originally WordPress at `http://robotlibrarian.billdueber.com/`), built
with [Hugo](https://gohugo.io/). Post and page bodies are **AsciiDoc**
(`.adoc`); the design is a minimal, "Morning"-inspired theme (Montserrat
headings, white-on-light-gray).

## Contents

```
hugo/
├── hugo.toml                     # Site config (URLs, taxonomies, AsciiDoc)
├── mise.toml                     # Pins Hugo 0.164.0 for this directory
├── content/
│   ├── about-bill.adoc           # "About Bill" page
│   └── posts/*.adoc              # 78 posts (front matter + AsciiDoc body)
├── static/images/                # Images pulled down from the source site
└── themes/robotlibrarian/        # Custom minimal theme
```

URLs mirror the original WordPress structure: `/YYYY/MM/<slug>/` for posts,
`/about-bill/` for the About page, `/tags/<tag>/` for tag archives.

## Requirements

- [mise](https://mise.jdx.dev/) (to install the pinned Hugo version)
- `asciidoctor` on `PATH` (Ruby gem or `brew install asciidoctor`)
- Python 3 for the one-time converter (`convert.py`)

## Build

```sh
cd hugo
mise install                    # installs the pinned Hugo
hugo                            # writes ./public/
hugo server                     # dev server
```

The build must finish with **no errors**. Hugo invokes `asciidoctor` to render
the `.adoc` content; that external binary is whitelisted in `hugo.toml`
under `[security.exec]`.

## Regenerating content from WordPress

`../convert.py` parses `../robotlibrarian.WordPress.2026-08-08.xml` (a
WordPress WXR export) and writes the site's `content/`:

```sh
python3 convert.py
```

It converts WordPress HTML to idiomatic AsciiDoc: headings, paragraphs, lists
(nested), blockquotes, tables, inline code/links/emphasis, and
`<pre><code class="language-X">` blocks. It also:

- **Fixes** obviously-broken source artifacts (unclosed brackets that would
  swallow a paragraph become literal text via an HTML entity; blocks are
  separated by blank lines so listings/headings aren't mis-parsed).
- Preserves original post dates/slugs/tags in front matter.
- Pulls the post's embedded images down into `static/images/` and rewrites
  links to the local copies (full-size "click to enlarge" copies included).
- Skips the spam-trap "HoneyPot" page and the old `custom_css` export item.

## Layout

`themes/robotlibrarian/` is a self-contained theme:

- `layouts/_default/baseof.html` — HTML skeleton
- `layouts/index.html` — paginated post list (home)
- `layouts/_default/single.html` — single post/page
- `layouts/_default/list.html` — tag archives + section lists
- `layouts/partials/` — head/header/footer/tags/pagination
- `static/css/style.css` — theme stylesheet

To switch the canonical site URL, edit `baseURL` in `hugo.toml`.
