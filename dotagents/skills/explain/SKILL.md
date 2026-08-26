---
name: explain
description: Explain a topic, piece of code, error, or decision to a smart 15-year-old as a visual HTML artifact with big pictures and few words. Use when the user runs /explain <topic>, or asks for an ELI15 / plain-language / intuitive explanation, "break this down", "dumb it down", or "explain this to me like I'm new to this".
---

Explain the subject in `$ARGUMENTS` (or, with no argument, the thing this session has been working on) to a curious 15-year-old: smart, reads quickly, knows nothing about this field. No prior jargon assumed; no condescension either.

## Step 1: understand it first

Do not explain from memory of the topic name. Read the actual thing:

- Code: read the relevant files and understand what it does and why it exists before translating.
- Error message: find the root cause, not the surface text.
- Document or concept: pull out the essential "what" and "why", and note where the simple version stops being true.

## Step 2: pitch

- Assume high-school math, science, and reading. Fractions, percentages, basic graphs, simple algebra are fine; calculus, probability notation, and field terms are not, unless introduced on the spot.
- Introduce at most 5 new terms, each the moment it is needed, with a one-line definition and the everyday thing it resembles.
- Purpose before mechanism. Nobody cares how it works until they know why it exists.
- Order: one sentence on why they should care; the mechanism; one concrete worked example; the one thing people usually get wrong; "so what" for them.
- Analogies must be real and hold up; if one breaks, say where.
- Simplify ruthlessly. The core idea landing at 80% accuracy beats a 100% accurate version that loses the reader. Flag the one simplification that matters most in a short "what I left out" line at the end.
- Tone: direct, a little casual, no "fellow kids" energy, no exclamation-mark enthusiasm.
- Few words per screen. A paragraph past four lines gets cut or turned into a picture.

## Step 3: format

Deliver as an HTML artifact: load the `artifact-design` skill first, and `artifact-diagramming` for the diagrams. Typography is fixed, do not pick fonts: the system UI stack for everything (`-apple-system, BlinkMacSystemFont, system-ui, "Segoe UI", sans-serif`, i.e. SF Pro on a Mac) and `ui-monospace, "SF Mono", Menlo, monospace` for code; no Google Fonts link. Headings get weight 700 and slight negative letter-spacing. Big pictures, few words:

- One idea per section, each with an inline SVG diagram or a large illustrated figure that carries the meaning on its own; the text underneath is a caption, not an essay.
- Show numbers as a picture (bars, timelines, boxes scaled to size) rather than a table wherever a comparison is the point.
- Finish with a 3-bullet "if you remember one thing" recap, the "what I left out" line, and 2-3 questions the reader could look up next.
- Total length: about a five-minute read.

Publish with the Artifact tool and reply with the link plus a one-sentence summary. Do not paste the explanation as terminal text.
