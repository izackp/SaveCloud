# Pure.CSS: The Complete Usage Cheatsheet

## 1. Starter Template

    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Pure.css</title>
      <!-- Core Pure.css -->
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/purecss@3.0.0/build/pure-min.css">
      <!-- Responsive Grids (required for responsive behavior) -->
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/purecss@3.0.0/build/grids-responsive-min.css">
      <!-- Pure CSS Utilities (optional but highly recommended for flexibility) -->
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/purecss-utilities@1.0.6/dist/all.css">
    </head>
    <body>
      <!-- Your content here -->
    </body>
    </html>

> Core Pure.CSS is **~4KB** minified/gzipped. Utilities add helper classes for spacing, colors, etc.

## 2. Responsive Grids

**Basic grid (always equal columns):**

    <div class="pure-g">
      <div class="pure-u-1-3">33.33%</div>
      <div class="pure-u-1-3">33.33%</div>
      <div class="pure-u-1-3">33.33%</div>
    </div>

Common unit sizes: `pure-u-1-2` (50%), `pure-u-1-4` (25%), `pure-u-3-4` (75%), `pure-u-1-5` (20%), etc.

**Mobile‑first responsive (stack on small screens, 50/50 on medium+):**

    <div class="pure-g">
      <div class="pure-u-1 pure-u-md-1-2">Column 1</div>
      <div class="pure-u-1 pure-u-md-1-2">Column 2</div>
    </div>

**Complex responsive (three breakpoints):**

    <div class="pure-g">
      <div class="pure-u-1 pure-u-md-1-3 pure-u-lg-1-4">1</div>
      <div class="pure-u-1 pure-u-md-1-3 pure-u-lg-2-4">2</div>
      <div class="pure-u-1 pure-u-md-1-3 pure-u-lg-1-4">3</div>
    </div>

## 3. Forms

**Base class:** `pure-form`

**Inline form (default):**

    <form class="pure-form">
      <input type="text" placeholder="Username">
      <input type="email" placeholder="Email">
      <button type="submit" class="pure-button">Submit</button>
    </form>

**Stacked form (labels above inputs):**

    <form class="pure-form pure-form-stacked">...</form>

**Aligned form (labels right‑aligned on large screens):**

    <form class="pure-form pure-form-aligned">
      <div class="pure-control-group">
        <label for="name">Name</label>
        <input type="text" id="name" placeholder="Name">
      </div>
      <div class="pure-control-group">
        <label for="email">Email</label>
        <input type="email" id="email" placeholder="Email">
      </div>
      <div class="pure-controls">
        <button type="submit" class="pure-button pure-button-primary">Sign Up</button>
      </div>
    </form>

**Grouped inputs (attached):**

    <div class="pure-group">
      <input type="text" placeholder="First name">
      <input type="text" placeholder="Last name">
      <input type="email" placeholder="Email">
    </div>
    <button class="pure-button pure-button-primary">Send</button>

**Input sizing & rounding:**

    <input type="text" class="pure-input-1 pure-input-rounded" placeholder="Full width, rounded">

## 4. Buttons

**Base class:** `pure-button`

    <button class="pure-button">Default</button>
    <button class="pure-button pure-button-primary">Primary</button>
    <button class="pure-button pure-button-disabled" disabled>Disabled</button>
    <a href="#" class="pure-button pure-button-active">Active Link</a>

**Button groups (attached):**

    <div class="pure-button-group" role="group">
      <button class="pure-button">Save</button>
      <button class="pure-button">Edit</button>
      <button class="pure-button">Delete</button>
    </div>

## 5. Tables

**Base class:** `pure-table`

    <table class="pure-table pure-table-striped pure-table-bordered">
      <thead>
        <tr><th>Name</th><th>City</th><th>Phone</th></tr>
      </thead>
      <tbody>
        <tr><td>John Doe</td><td>New York</td><td>123-456-7890</td></tr>
      </tbody>
    </table>

Variations: `pure-table-bordered`, `pure-table-horizontal`, `pure-table-striped`.

## 6. Menus

**Vertical menu (default):**

    <div class="pure-menu">
      <span class="pure-menu-heading">Brand</span>
      <ul class="pure-menu-list">
        <li class="pure-menu-item"><a href="#" class="pure-menu-link">Home</a></li>
        <li class="pure-menu-item pure-menu-selected"><a href="#" class="pure-menu-link">Products</a></li>
        <li class="pure-menu-item pure-menu-disabled"><span class="pure-menu-link">Disabled</span></li>
      </ul>
    </div>

**Horizontal menu:** add `pure-menu-horizontal`

    <div class="pure-menu pure-menu-horizontal">
      <ul class="pure-menu-list">
        <li class="pure-menu-item pure-menu-selected"><a href="#" class="pure-menu-link">Home</a></li>
        <li class="pure-menu-item"><a href="#" class="pure-menu-link">News</a></li>
      </ul>
    </div>

States: `pure-menu-selected`, `pure-menu-disabled`, `pure-menu-scrollable`.

## 7. Utilities Library (purecss-utilities)

Include the CDN (already in starter template). This adds hundreds of helper classes.

### Text colors

Full list: `pure-txt-black`, `pure-txt-blue`, `pure-txt-cyan`, `pure-txt-green`, `pure-txt-grey`, `pure-txt-magenta`, `pure-txt-red`, `pure-txt-white`, `pure-txt-yellow`.

    <span class="pure-txt-red">Error message</span>
    <span class="pure-txt-green pure-txt-xl">Success! Large green text</span>

### Text opacity

`pure-txt-alpha-10`, `20`, `25`, `30`, `40`, `50`, `60`, `70`, `75`, `80`, `90`, `100`.

    <p class="pure-txt-grey pure-txt-alpha-50">50% opaque grey</p>

### Text sizes

`pure-txt-xxs` (0.7rem), `xs` (0.8rem), `sm` (0.9rem), `md` (1rem), `lg` (1.1rem), `xl` (1.2rem), `xxl` (1.3rem).

### Background colors

Same colors as text, prefixed with `pure-bg-`. Examples:

    <div class="pure-bg-blue pure-txt-white">Blue background, white text</div>
    <div class="pure-bg-yellow pure-txt-black pure-p-2">Yellow background with padding</div>

Background opacity: `pure-bg-alpha-10` through `100`.

### Spacing utilities

Uses `--pureSpacingUnit` (0.25rem). Pattern: `pure-{p|m}{t|b|l|r|x|y}-{0..24}`.

- Padding: `pure-p-2` (0.5rem all sides), `pure-pt-4` (1rem top), `pure-px-3` (0.75rem left/right)
- Margin: `pure-m-0` (no margin), `pure-mt-2`, `pure-mx-auto` (auto left/right)

Example:

    <div class="pure-bg-grey pure-p-4 pure-mb-2">Padding 1rem, margin bottom 0.5rem</div>

### Border utilities

Width: `pure-bd-1` (1px), `pure-bd-2`, `pure-bd-3`, `pure-bd-4`, `pure-bd-5`.

Style: `pure-bd-solid`, `pure-bd-dotted`, `pure-bd-dashed`.

Color: `pure-bd-black`, `pure-bd-blue`, `pure-bd-cyan`, `pure-bd-green`, `pure-bd-grey`, `pure-bd-magenta`, `pure-bd-red`, `pure-bd-white`, `pure-bd-yellow`.

    <div class="pure-bd-2 pure-bd-solid pure-bd-red pure-p-2">2px solid red border</div>

## 8. Common Patterns

**Centered, constrained content:**

    <div class="pure-g" style="max-width: 800px; margin: 0 auto;">
      <div class="pure-u-1">
        Centered content.
      </div>
    </div>

**Responsive image:**

    <img class="pure-img" src="photo.jpg" alt="Description">

**Custom overrides (add your own CSS after Pure):**

    <style>
      .custom-button {
        background-color: #ff6600;
        border-radius: 8px;
      }
    </style>
    <button class="pure-button custom-button">Custom Button</button>

## 9. Final Notes

- **Dropdown menus** are supported but need a small JavaScript to enable submenus. See the [official example script](https://pure-css.github.io/js/menus.js).
- **Browser support**: modern browsers + IE10+ (thanks to Normalize.css).
- **Modularity**: you can import only the modules you need (grids, forms, buttons, etc.) via custom build.

End of cheatsheet.