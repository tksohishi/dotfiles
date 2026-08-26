---
name: explain
description: Explain a topic to a smart 15-year-old as a visual HTML artifact with big pictures and few words. Use when the user runs /explain <topic>, or asks for an ELI15 / plain-language / intuitive explanation of a concept, system, codebase, or decision.
---

Explain the topic in `$ARGUMENTS` (or, with no argument, the thing this session has been working on) the way you would to a curious 15-year-old: someone who is smart and reads quickly but knows nothing about this field. No prior jargon assumed; no condescension either.

## Pitch

- Assume high-school-level math, science, and reading. Fractions, percentages, basic graphs, and simple algebra are fine; calculus, probability notation, and field-specific terms are not, unless introduced on the spot.
- Introduce at most 5 new terms, each the moment it is needed, with a one-line definition and the everyday thing it resembles.
- Lead with the "why should I care" in one sentence, then the mechanism, then one concrete worked example, then the one thing people usually get wrong.
- Analogies must be real and hold up; if an analogy breaks, say where it breaks.
- Few words per screen. If a paragraph runs past four lines, cut it or turn it into a picture.

## Format

Deliver as an HTML artifact: load the `artifact-design` skill first, and `artifact-diagramming` for the diagrams. Big pictures, few words:

- One idea per section, each with an inline SVG diagram or a large illustrated figure that carries the meaning on its own; the text underneath is a caption, not an essay.
- Show numbers with a picture (bars, timelines, boxes scaled to size) rather than a table wherever a comparison is the point.
- Finish with a 3-bullet "if you remember one thing" recap and 2-3 questions the reader could go look up next.
- Total length: about a five-minute read.

Publish with the Artifact tool and reply with the link plus a one-sentence summary. Do not paste the explanation as terminal text.
