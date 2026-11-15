# EBD IADP Design System

## Source of truth

Use this document for all future UI work in this project. The supplied visual reference is the EBD IADP dashboard: warm editorial dashboard, dark brown navigation, cream canvas, white rounded cards, amber and peach accents.

## Visual theme

Warm, calm, church/community administration dashboard. Dense enough for operational data, but with generous whitespace and soft rounded cards. Avoid generic blue SaaS styling.

## Colors

- `--ds-bg`: `#F3EBE4` — page canvas.
- `--ds-surface`: `#FFFFFF` — cards and panels.
- `--ds-ink`: `#1F1611` — primary text and dark navigation.
- `--ds-muted`: `#6F675F` — secondary text.
- `--ds-line`: `#E5DED7` — subtle borders.
- `--ds-amber`: `#F5B83D` — primary highlight, active states, key data.
- `--ds-peach`: `#E5AE92` — secondary highlight.
- `--ds-soft`: `#F8F3EF` — muted surfaces.
- `--ds-green`: `#5DCAA5` — positive/attendance states.

Dark mode should keep the same hierarchy with `#0B0B0B` canvas, dark brown surfaces, cream text, and amber/peach accents.

## Typography

Keep the supplied project fonts: Figtree for UI/body and Outfit for display numbers when appropriate. Do not add a second font family unless the design explicitly requires it.

## Components

- Cards: white, 18–22px radius, 1px warm border, very soft shadow.
- Primary buttons: dark brown background, cream text, 10–12px radius.
- Accent buttons: amber background with dark brown text.
- Pills/tags: compact, rounded, used sparingly.
- Navigation: dark brown desktop sidebar; bottom navigation on mobile.
- Inputs: white/cream surfaces, warm border, 10px radius, visible focus ring.

## Layout

- Desktop breakpoint: 900px.
- Desktop uses a 230–250px left navigation rail and a fluid content area.
- Mobile keeps the existing bottom navigation and stacks dashboard cards.
- Use 16px base spacing, with 24px and 32px section spacing.
- Do not use fixed widths for the main content area.

## Interaction states

Hover: slightly darker/lighter surface without aggressive transforms.
Focus: visible 2px amber outline.
Active navigation: amber indicator and cream/white label.
Disabled: reduced opacity, no layout shift.

## Do / Don't

Do reuse existing data, actions, Supabase logic, fonts and assets.
Do scope new visual rules to components/classes instead of rewriting application behavior.
Don't replace functional views with static mockups.
Don't introduce a new framework or duplicate the existing design system.
Don't use blue as the primary brand color.
