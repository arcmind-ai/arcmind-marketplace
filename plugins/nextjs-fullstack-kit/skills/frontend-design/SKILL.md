---
name: frontend-design
description: Generate distinctive, production-grade frontend interfaces that avoid generic AI aesthetics. Activates automatically during frontend work or on-demand for UI generation.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
argument-hint: "UI description"
---

# Frontend Design

Create distinctive, production-grade UI for: **$ARGUMENTS**

## Design thinking — before you write any code

Establish a clear creative direction first. Answer these questions:

1. **Purpose & audience** — What problem does this solve? Who uses it? A developer tool feels different from a consumer app.
2. **Tone** — Pick a specific aesthetic direction and commit to it:
   - Brutally minimal · Maximalist · Retro-futuristic · Luxury · Playful · Brutalist · Art deco · Soft organic · Industrial · Editorial · Swiss/International · Cyberpunk · Warm craft · Glass morphism · Neo-Memphis
3. **Constraints** — What's the framework context? (Next.js App Router, Server vs Client components, Tailwind config, existing design tokens)
4. **The hook** — What single detail will make this memorable? Every great UI has one.

**The rule: choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.**

## Implementation standards

Your output must be:
- **Functional** — production-grade, not a demo
- **Visually striking** — someone should pause and look twice
- **Cohesive** — every element supports the chosen direction
- **Refined** — sweat the details others skip

## Typography

Choose fonts that are beautiful, unique, and interesting.

**Avoid:** Arial, Inter, Roboto, system-ui defaults, anything that screams "I didn't think about this."

**Do:** Pick a distinctive display font paired with a refined body font. Use Google Fonts, Fontsource, or `next/font` for optimal loading.

```tsx
// next/font example — always prefer this in Next.js projects
import { Space_Grotesk, Instrument_Serif } from "next/font/google";

const heading = Space_Grotesk({ subsets: ["latin"], variable: "--font-heading" });
const body = Instrument_Serif({ subsets: ["latin"], variable: "--font-body" });
```

Typography hierarchy matters more than font choice. Vary size, weight, letter-spacing, and line-height with purpose.

## Color & theme

Commit to a cohesive palette via CSS variables or Tailwind config. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.

```css
/* Define tokens — adapt to project's existing token system if one exists */
:root {
  --color-surface: #0a0a0b;
  --color-text: #fafaf9;
  --color-accent: #e11d48;
  --color-muted: #71717a;
}
```

**Avoid:** Purple-to-blue gradients (the #1 "AI-generated" cliche), rainbow palettes, low-contrast pastels everywhere.

**Do:** Study real products you admire. Steal palettes from photography, architecture, film.

## Motion & animation

Prioritize high-impact moments over scattered micro-interactions:

1. **Page-load orchestration** — Staggered reveals that guide the eye
2. **Scroll-triggered transitions** — Content that earns attention as it enters
3. **State transitions** — Meaningful feedback on interaction

Prefer CSS animations/transitions over JS animation libraries when possible. Use `will-change` sparingly and respect `prefers-reduced-motion`:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Spatial composition

Break the grid (intentionally):

- **Asymmetric layouts** — not everything needs to be centered
- **Overlap** — elements that break boundaries create depth
- **Diagonal flow** — guide the eye through the page
- **Generous negative space** OR **controlled density** — both work, muddled middle doesn't
- **Grid-breaking hero elements** — the most important thing should feel different

## Visual details

Layer effects to create atmosphere:

- Subtle gradients on surfaces (not rainbow backgrounds)
- Texture overlays (noise, grain, fabric)
- Thoughtful shadows (layered, colored, not just `shadow-lg`)
- Borders and dividers with purpose
- Context-specific details — a music app feels different from a finance dashboard

## What to avoid — the "AI look"

These patterns instantly signal "AI-generated, no designer involved":

- Generic sans-serif font, no hierarchy
- Purple/blue gradient backgrounds
- Perfectly symmetric card grids with rounded corners
- Gratuitous glassmorphism on everything
- Rainbow gradient text for emphasis
- Identical spacing and sizing everywhere
- No personality, no opinion, no point of view

## Adapting to the project

Before generating UI, check the project context:

1. **Existing design system** — Read `tailwind.config.ts`, check `src/components/ui/` for existing primitives. Reuse what's there.
2. **CSS variables / tokens** — If the project has design tokens, use them. Don't introduce competing systems.
3. **Server vs Client** — Default to Server Components. Only add `"use client"` when you need interactivity (onClick, useState, useEffect). Keep data fetching server-side.
4. **Existing patterns** — Match the codebase. If they use a component library (shadcn, Radix, etc.), build on top of it.

## Complexity matching

Match implementation to vision:

- **Maximalist design** → elaborate code is expected. Layered animations, complex layouts, multiple visual effects.
- **Minimalist design** → every pixel matters. Precision in spacing, typography scale, and restraint. Fewer lines of code, more impact per line.
- **Dashboard / data-heavy** → clarity over flair. Typography hierarchy, whitespace, and information density done right.
- **Landing / marketing** → maximum visual impact. Hero animations, scroll effects, bold typography.
- **Internal tool** → speed and usability. Clean layout, obvious hierarchy, no unnecessary decoration.

The worst outcome is a maximalist vision with minimalist execution, or decoration piled onto what should be clean.
