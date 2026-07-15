---
schema: design-sprint
version: 1
design_approved:
initiative_type: iteration
---

# Design Sprint — Example Feature

**initiative_id:** EXAMPLE-001
**date:** 2026-01-01
**status:** draft

---

## Design Hypothesis

We believe replacing the disappearing spinner with a persistent success/error toast will result in
fewer duplicate export submissions because users will have unambiguous confirmation that the export
finished (or didn't), instead of guessing.

## User Flows

### Export — Happy Path

User clicks "Export" → spinner shows → spinner is replaced by a green success toast with a
download link → toast dismisses after 6 seconds or on manual close.

### Export — Edge Cases

If the export takes longer than 20 seconds, show an inline "still working" message instead of
leaving a bare spinner.

### Export — Error States

If the export fails, show a red error toast with a "Retry" action. Do not auto-dismiss error toasts.

## Information Architecture

No navigation changes — this is a local UI state change on the existing export button.

## Interaction Design Notes

Toast enters from the bottom-right with a short slide-in transition; success and error toasts use
distinct colors and icons so the two states are distinguishable without reading the text.

## Wireframes

| Screen | Description | Link |
|---|---|---|
| Export button (success) | Green toast with download link | n/a — placeholder for this example |
| Export button (error) | Red toast with retry action | n/a — placeholder for this example |

## Visual Direction

**Design tokens:**
- Primary colour: existing success green token
- Secondary colour: existing error red token
- Typography: existing body font
- Border radius: existing card radius
- Spacing scale: existing spacing scale

**Component concepts:** Toast component (success/error variants)
**Moodboard:** n/a — reuses existing design system

## MVP Scope (new_product only)

n/a — this is an iteration, not a new product.

## MVP Validation Experiments (new_product only)

n/a — this is an iteration, not a new product.

## Reviewer Verdict

**Verdict:** approved
**Rationale:** Small, self-contained UI change reusing existing design tokens and components.

---

## Human Gate 2

**decision_date:**
**decision_rationale:**
**iteration_notes:**
