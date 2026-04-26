# UI Design Cheatsheet

Based on established best practices and expert consensus (2025), this cheatsheet covers the core principles of typography, layout, color, negative space, and visual hierarchy.

---

## 1. Typography

Good typography is invisible – it supports readability and brand personality without drawing attention to itself.

### Font Selection & Scale
- Limit your design to **two font families maximum** (one for headings, one for body text).
- Establish a consistent type scale (e.g., using a modular scale) and reuse it across all components.
- If a third typeface is needed, give it a narrow, specific function (e.g., code snippets, data tables).

### Sizing & Line Height
- Body text: **minimum 16px** to prevent eye strain.
- Line height:
  - Body text: **1.5× the font size** (e.g., 16px font → 24px line height).
  - Headings: **~1.2× the font size** for tighter, more impactful grouping.

### Readability
- Line length: **45–75 characters per line** (including spaces).
- Alignment: **Left-align** longer text blocks. Centered alignment reduces scanability.

### Design with Real Content
- Avoid placeholder text (e.g., “Lorem Ipsum”) – it hides layout issues such as awkward line breaks, truncation, or overflow.

---

## 2. Text Layout

Standardised layouts make interfaces predictable and easy to navigate.

### Visual Prioritisation
- Use a clear hierarchy of **size, weight, colour, spacing, and placement**.
- Limit primary text hierarchy to **three levels** (heading, subheading, body) to avoid cognitive overload.
- Task completion rates improve measurably when text follows a clear visual order.

### Logical Reading Order
- Structure content semantically: `H1 > H2 > H3 > …`.
- Correct heading levels help screen‑reader users understand information structure.

### White Space Within Text
- Use margins, padding, and generous line spacing (see line‑height above) to break up long passages.
- Well‑spaced text signals clarity and premium quality.

---

## 3. Colors

Colour shapes usability, brand perception, and emotional response. A beautiful palette must also be functional.

### Build a Harmonious Palette
- Start with **grayscale** (black, white, grey tones) – then introduce colour only where it serves a function (e.g., buttons, alerts, links).
- Use the **60‑30‑10 rule**:
  - 60% dominant (backgrounds)
  - 30% secondary (sections, panels)
  - 10% accent (CTAs, highlights)

### Colour Psychology (General Guidance)
- **Blue** → trust, professionalism (common in finance, tech).
- **Red** → urgency, action (sales, critical alerts).
- Be consistent: never change the colour of links or buttons arbitrarily inside the same interface.

### Accessibility – Contrast
- Follow WCAG 2.1 minimum contrast ratios:
  - Normal text (under 24px): **4.5:1**
  - Large text (24px+ / bold 19px+): **3:1**
- **Never rely on colour alone** to convey meaning. Use icons, labels, or patterns as redundant cues (for colour‑blind users and screen readers).

---

## 4. Negative Space (Whitespace)

Whitespace is not “empty” – it guides attention, reduces cognitive load, and creates sophistication.

### Macro vs. Micro Whitespace
- **Macro whitespace**: large gaps between major sections or distinct elements (e.g., between a hero area and a feature grid).
- **Micro whitespace**: internal padding inside components (e.g., between a button’s text and its border, or between lines of text).

### Consistent Grid System
- Use a **base unit** (commonly 8px) for all margins, padding, and layout gaps.
- Elements with more space around them are perceived as **more important** than those tightly packed.

### Strategic Breathing Room
- A cluttered interface destroys usability. Whitespace improves comprehension, focus, and perceived value.

---

## 5. Highlighting & Contrasting Important Information

Effective visual hierarchy tells users exactly where to look.

### Contrast Beyond Colour
- Create contrast through:
  - **Size** (larger = more important)
  - **Weight** (bold vs. regular)
  - **Spacing** (more space around high‑priority items)
  - **Shape** (e.g., distinct button boundaries)
  - **Elevation / shadows** (layered cards, modals)

### Interactive Elements
- Buttons, links, and form fields must have clear **visual cues** (border, background, shadow, underline).
- Ensure they meet contrast requirements not only in default state but also in hover, focus, and active states.

### Test in Monochrome (Grayscale)
- Turn off colour in your design tool or browser to verify that meaning and hierarchy still hold.
- If you cannot tell what is clickable or important without colour, you need to add non‑colour cues.

### Elevation & Depth
- Use shadow and layering to separate foreground elements from background.
- This reduces the need for extra borders or colours while still communicating hierarchy.

---

## Quick Reference Table

| Area                 | Best Practice (Minimum / Guideline)                                                                 |
| -------------------- | --------------------------------------------------------------------------------------------------- |
| **Typography**       | Body: 16px / 1.5 line‑height / 45‑75 chars / left‑aligned. Headings: 1.2 line‑height.              |
| **Colour & Contrast**| WCAG AA: 4.5:1 normal text, 3:1 large text. Colour‑blind safe; never colour alone.                 |
| **Negative Space**   | Use 8px base grid. More space around an element = higher perceived importance.                     |
| **Visual Hierarchy** | Combine size, weight, colour, spacing, and elevation. Limit to 3–4 tiers of importance.            |
| **Layout & Scanning**| Logical heading order, semantic HTML structure, consistent alignment, generous macro spacing.      |

---

## Practical Application (General Principles)

- **Use design tokens** – standardise colour, spacing, and typography values. This guarantees consistency across your interface and makes developer handoff reliable.
- **Test with real content** – placeholder text hides real‑world layout issues. Always test with actual copy, images, and data early in the process.
- **Check accessibility without tools** – zoom to 200%, use greyscale mode, and try navigating only with a keyboard. If anything breaks or becomes unclear, redesign.
- **Communicate technical requirements clearly** – minimum font sizes, responsive breakpoints, and all interactive states (hover, focus, disabled) must be agreed upon before implementation.