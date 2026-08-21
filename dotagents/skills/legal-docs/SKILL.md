---
name: legal-docs
description: Prepare Terms of Use, Privacy Policy, and related legal documents for the current project if not present yet, using the CC0 General-Legal/legal-templates as the base and a scope interview before drafting. Use when the user asks for terms of service/use, privacy policy, cookie notice, NDA, DPA, or "legal docs" for a project or product launch.
---

# legal-docs

Draft the legal documents a project needs before shipping (Terms of Use, Privacy Policy, cookie notice, etc.). Templates come from [General-Legal/legal-templates](https://github.com/General-Legal/legal-templates) (CC0 1.0, free to reuse and modify). The workflow borrows from Anthropic's claude-for-legal drafting skills: interview before drafting, flag every judgment call, output as a draft for review.

Not legal advice: everything produced here is a draft for review by a qualified legal professional. Say so in the final report, and never present output as ready to publish.

## Step 1: Check what already exists

Search the project for existing legal docs before drafting anything:

```
fd -i -e md -e html -e txt . --full-path | rg -i 'terms|privacy|legal|tos|cookie|license' 
rg -li 'terms of (use|service)|privacy policy' --glob '!node_modules'
```

If docs exist, report what's there and ask whether the user wants a review/update instead of new drafts. Don't overwrite existing legal documents without explicit confirmation.

## Step 2: Scope interview

Do not skip to drafting. Determine, from the repo (README, package config, deployed URLs) what you can, and ask the user for the rest:

- **Which documents** — default suggestion: Terms of Use + Privacy Policy; add cookie-notice if the site sets non-essential cookies.
- **Legal entity** — company name (and state/country of incorporation) or individual; governing law preference.
- **Product** — name, domain(s), what it does, paid or free, user accounts or not.
- **Data practices** — what personal data is collected (accounts, analytics, payments, logs), third-party processors (Stripe, Google Analytics, hosting), whether data is sold/shared.
- **Audience/jurisdiction** — US-only, EU users (GDPR), California users (CCPA/CPRA), children under 13 (COPPA is a red flag; escalate to a lawyer).
- **Contact** — email for privacy/legal inquiries.

Pick the privacy template by jurisdiction: `privacy-policy-us` (CCPA/CPRA) for US-focused, `privacy-policy-gdpr` for EU-facing. If both apply, start from GDPR and merge the CCPA sections, and flag the merge for review.

## Step 3: Fetch templates

Raw URL pattern:

```
https://raw.githubusercontent.com/General-Legal/legal-templates/main/templates/<slug>/template.md
```

Relevant slugs: `terms-of-use`, `privacy-policy-us`, `privacy-policy-gdpr`, `cookie-notice`. (The repo also has `mutual-nda`, `one-way-nda`, `dpa-us`, `dpa-global`, `master-services-agreement`, `advisor-agreement`, `business-associate-agreement`, `employee-offer-letter` if asked.) Save fetched templates to the project's `tmp/` before editing.

## Step 4: Fill and adapt

- Fields to customize are wrapped in `<mark>` tags (e.g. `<mark>[Company]</mark>`, `<mark>[DOMAIN NAME]</mark>`, `<mark>_____________</mark>` for dates). Replace each with the interview answers and strip the `<mark>` wrapper.
- Delete sections that don't apply (e.g. payment terms for a free product) rather than leaving placeholders; note each deletion.
- Where a real judgment call remains (arbitration clause, liability caps, data-retention periods, governing law when the user had no preference), keep sensible template language but tag it inline with `[REVIEW: <question>]`.
- Set the effective date to today; grep the final files for `<mark>` and `[` to confirm nothing unfilled slipped through.

## Step 5: Output

- Write to `docs/legal/terms-of-use.md` and `docs/legal/privacy-policy.md` unless the project has an obvious existing home (a website's `content/`/`pages/` dir, `public/`).
- Prepend to each file an HTML comment: `<!-- DRAFT for legal review — not yet reviewed by counsel. Based on General-Legal/legal-templates (CC0). -->`
- Final report: list files created, every `[REVIEW: ...]` flag as a checklist, and the disclaimer that a qualified legal professional should review before publishing. Escalate explicitly if the product touches health data (HIPAA), children (COPPA), or financial regulation — templates are not sufficient there.
- Don't commit unless the project's conventions say to; legal drafts warrant user review first.
