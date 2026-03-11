# UI/UX Design System

## Layout

### App Shell
- **Desktop**: Sidebar (240px) + main content area
- **Tablet**: Collapsible sidebar
- **Mobile**: Bottom navigation + full-width content

### Breakpoints
| Name | Min width | Usage |
|------|-----------|-------|
| `sm` | 640px | Mobile landscape |
| `md` | 768px | Tablet |
| `lg` | 1024px | Desktop |
| `xl` | 1280px | Wide desktop |

## Component Catalogue

| Component | Location | Usage |
|-----------|----------|-------|
| Button | `src/components/ui/button.tsx` | All clickable actions |
| Input | `src/components/ui/input.tsx` | Text inputs, search |
| Card | `src/components/ui/card.tsx` | Content containers |

## Color Tokens

Use Tailwind CSS classes. Define custom tokens in `tailwind.config.ts`.

## Spacing

Use Tailwind spacing scale (4px base).

## Typography

- **Headings**: `font-semibold`, sizes: `text-2xl` (h1), `text-xl` (h2), `text-lg` (h3)
- **Body**: `text-sm` (default), `text-xs` (secondary)

## Interaction Patterns

| State | Pattern |
|-------|---------|
| Loading | Skeleton placeholders (not spinners) |
| Error | Toast notification + inline message |
| Empty | Illustration + descriptive text + CTA button |
| Success | Toast notification (auto-dismiss 3s) |
| Confirmation | Dialog with explicit action buttons |
