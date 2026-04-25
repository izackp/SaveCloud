# Product

## Register

product

## Users

The web UI is opened by the operator who runs SaveCloud and a small ring of trusted power users who got accounts directly from them. They are mostly technical: comfortable with UUIDs, hashes, sessions, raw record IDs. Not all of them are engineers, so the UI has to be self-explaining without docs, but it should never apologise for showing real data. Sessions tend to be focused and short: someone is here to inspect a save, fix a record, reseed the database, change a password, or audit who's logged in. There is no end-user player-facing surface in this UI; players talk to the REST API through the C library and native clients.

## Product Purpose

SaveCloud is a self-hostable backend for game-save files keyed by game hash. The web UI is the operator's instrument panel: a way to look at users, sessions, games, game hashes, and saves, and to perform a small set of administrative actions (login, password change, reseed, delete). It exists so the operator never has to drop into a SQLite shell to answer "who is this?", "what does this save belong to?", or "why didn't this client sync?".

Success looks like an operator getting an answer or finishing an action in a single uninterrupted glance, on a quiet screen, with no ceremony.

## Brand Personality

Calm. Honest. Workshop-built.

Voice is plain and engineer-direct, the same register as the README and the Swift source. Headings are nouns, not slogans. Buttons say what they do. Errors describe what went wrong and what the operator can do next, without exclamation points and without "oops". The interface should feel like a serious instrument that respects the operator's time and competence, the same way a good text editor or a good packet inspector does.

Emotional goal: confidence. Opening this UI should feel like sitting down at a clean workbench. Closing it should feel like the system is in order.

## Anti-references

- **Crypto / gamer neon.** Black backgrounds, neon cyan/magenta/green, hard glows, skewed angles, monospace as costume. The fact that this tool stores game saves does not make it a gamer brand; collapsing into that lane is the category-reflex move. Do not do it.
- **Consumer-app friendly.** Rounded-everything, illustrated empty states, mascot characters, exclamation-mark copy, "Welcome back, friend!" tone. This is a self-hosted operator tool, not a consumer app. The audience does not need to be cheered up.
- **The reflexive admin SaaS dashboard.** Big-number metric cards with tiny labels, gradient accents, sidebar of icon-only tabs with emoji, sterile blue-grey-white. Implicitly banned by the lane choice but worth naming so it does not creep back in via Pure.CSS defaults.
- **Untouched Pure.CSS.** Stock Pure.CSS with no overrides reads as an unfinished tutorial project. Pure.CSS is the chassis; the visual system on top of it is the work.

## Design Principles

1. **Readable without docs, dense with intent.** A trusted power user should be able to land on any page and understand what they are looking at within a few seconds, even if they have never seen the UI before. Density is allowed and welcomed, but every column, label, and action has to earn its position. Hidden cleverness is worse than a slightly long table.

2. **Raw data, dignified.** UUIDs, hashes, timestamps, and internal IDs are first-class content. The visual system has to make them legible (tabular figures, mono-flavoured type for fixed-width tokens, copy affordances where useful) rather than hiding them behind avatars or paraphrasing. The tool's job is to show the truth of the database.

3. **Calm under sustained use.** Operators stare at this UI while debugging. Contrast must be high enough to read at a glance, but the surface must not vibrate, glow, animate without reason, or compete for attention. One accent colour. One type family. No decorative motion. The eye should rest by default and only move when something actually changed.

4. **Single instrument, not a suite.** Resist the urge to add tabs, segmented controls, dashboards, and "modules" that turn the UI into a product portfolio. Every screen is one job: one resource, one list or one form, one primary action. Navigation reveals the small fixed set of things this tool actually does.

5. **Self-host first.** This runs on the operator's machine, on their data, for their users. No telemetry-flavoured patterns ("trending", "discover", "for you"), no cloud-vendor framing, no growth surfaces. The UI behaves as a local instrument that happens to be served over HTTP.

## Accessibility & Inclusion

Target WCAG 2.1 AA across the web UI:

- 4.5:1 minimum contrast for body text and 3:1 for large text and non-text UI affordances, including all interactive states (default, hover, focus, active, disabled).
- Never rely on colour alone. Status, validity, and selection use a redundant cue (label, icon, weight, position).
- All interactive elements are keyboard reachable in a sensible order, with a visible focus ring that is not removed by stylistic resets.
- Forms use real `<label for="…">` associations, real fieldsets, and real `aria-describedby` for error messaging.
- Tabular figures (`font-variant-numeric: tabular-nums`) on every column of IDs, dates, sizes, and counts so eyes can compare rows without sliding.
- Respect `prefers-reduced-motion`: any non-decorative motion shortens or disables under it.
- The interface must remain usable at 200% browser zoom and at a 360px viewport. The fixed sidebar collapses or moves rather than stealing content width on narrow screens.
