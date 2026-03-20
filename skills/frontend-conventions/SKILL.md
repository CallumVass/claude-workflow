---
name: frontend-conventions
description: Frontend Conventions Skill
---

# Frontend Conventions Skill

Before writing any frontend code, discover and follow the project's existing conventions.

## Discovery (do this first)

1. **Styling approach**: Check `package.json`, `tailwind.config.*`, `postcss.config.*`, existing components. Identify: Tailwind, CSS modules, styled-components, vanilla CSS, etc.
2. **Component library**: Check for DaisyUI, shadcn/ui, Radix, Headless UI, Vuetify, etc. Read their config/theme files.
3. **Theming**: If using Tailwind + DaisyUI, customize via `daisyui.themes` in `tailwind.config`. If using shadcn, use CSS variables in `globals.css`. If custom, find where tokens are defined.
4. **Existing patterns**: Read 2-3 existing components to understand naming, file structure, and how styles are applied.
5. **Icons**: Check for Lucide, Heroicons, FontAwesome, custom SVGs, or framework-specific icon packages.

## Rules

- **Use what's already there.** Never introduce a new styling system alongside an existing one. If the project uses Tailwind, use Tailwind utilities — don't write custom CSS classes. If it uses CSS modules, use CSS modules.
- **Extend the existing theme, don't bypass it.** Customize via the framework's theming mechanism (Tailwind config, DaisyUI themes, shadcn CSS variables, etc.) — not by overriding with raw values.
- **Match existing component patterns.** If the project wraps DaisyUI's `btn` with variants, follow that pattern. If it uses shadcn's `<Button variant="...">`, use that API.
- **No raw color/spacing values.** Use the project's token system — Tailwind classes, CSS variables, theme tokens, whatever the project uses.
- **Respect the utility-first boundary.** In Tailwind projects: use `@apply` sparingly, prefer utility classes. Don't create `@layer components` classes for one-off styles.

## When writing a design system (design-ui.sh)

If asked to create/update a design system for this project:

1. Discover the stack first (above).
2. Express the design system **in the project's native format**:
   - Tailwind + DaisyUI → DaisyUI theme config + Tailwind `extend` values
   - Tailwind + shadcn → CSS variables in the shadcn format
   - Tailwind (plain) → `tailwind.config` theme extensions
   - CSS modules / vanilla → CSS custom properties
   - Styled-components → theme object
3. Document design decisions (philosophy, font pairings, palette rationale) as comments in the config or in this file.
4. Update this file with the project-specific conventions once discovered.

## Anti-Patterns

- Introducing CSS custom properties in a Tailwind project (use config/theme instead)
- Writing `@layer` rules when utility classes suffice
- Adding a component library the project doesn't already use
- Hardcoding colors/spacing instead of using the project's tokens
- Fighting the existing styling system instead of extending it
