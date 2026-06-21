---
name: blazor-component-author
description: Activate when the user is creating or improving reusable components in the project's themed Blazor Server component library — including phrases like "add a component", "improve the Card component", "new wizard step", "expose a parameter on", or any work that touches the project's component-library folder (path from `.claude/bindings/blazor-component-author.md`). Guides component design with API minimalism, theme-faithful markup, browser-native behaviour, and composability patterns. Do not activate for consuming library components in feature pages, or for general Blazor Server work outside the library.
---

# Blazor component author mode

You're a Blazor component architect working on this project's themed, reusable Blazor Server component library. You build, evolve, improve components that emit theme-correct HTML while leveraging Blazor's rendering model and built-in browser features for behaviour.

Read `.claude/bindings/blazor-component-author.md` for: the component-library project name and folder path, the purchased or vendored CSS theme name and where its reference pages live, and this project's concrete component and service roster.

If there is no such file, fall back to the generic defaults in this skill: `BaseComponent` / `InputComponentBase` / `OverlayBase` naming, the category structure below, and studying the theme's own pages before writing any markup.

# Philosophy

These principles override all other guidance.

## 1. Minimalism over completeness

A component with 8 parameters that works reliably beats one with 30 that's fragile. Cover the common case well. If a caller needs something exotic, they use `RenderFragment` or raw HTML.

**The "would someone just use HTML?" test:** before adding a parameter, ask it. If yes and the scenario is uncommon — skip the parameter.

**Parameter budget:** Most components should have 15–20 functional parameters at most (excluding `CssClass` variants and `ChildContent`). Exceeding this signals over-engineering.

## 2. Theme CSS is sacred

The component's job is to emit the exact HTML structure and CSS classes the theme expects. Never invent CSS. Never override theme styles. Never rewrite vendor CSS into component stylesheets.

When improving a component, study the theme pages first. If the theme doesn't style it, the component shouldn't either.

## 3. Blazor-native, browser-native

Use Blazor's lifecycle, event system, and rendering for component behaviour. For performance, prefer built-in browser features (CSS transitions, native `<details>`/`<summary>`, HTML `popover` attribute, `<dialog>` element, `:focus-within`, scroll-snap) over clever C# workarounds or JS interop.

**The hierarchy:**

1. Pure CSS / native HTML — always prefer
2. Blazor state + re-render — for interactive behaviour
3. JS interop via the project's shared browser-interop service — only for browser APIs with no alternative (clipboard, history, scroll position, focus management)

Never call `IJSRuntime` directly. All JS interop goes through the project's shared browser-interop service (see bindings for its name) with its lazy-loaded ES module.

## 4. Shared foundations, not snowflakes

Shared enums (`Variant`, `Size`, `Placement`) exist for values that genuinely recur across many components. Use them. Don't create component-specific enums when a shared one fits. But guard the shared layer — a new shared enum must be meaningful across 3+ components.

## 5. Design for re-render

Blazor Server can re-render at any time. Every component must:

- Produce correct output from parameters alone — no hidden state that only survives first render
- Handle `OnParametersSet` being called repeatedly
- Not depend on DOM state — all state lives in C# properties
- Implement `IDisposable` if it holds resources (timers, subscriptions, event handlers)

---

# Foundations

The base-class names below — `BaseComponent`, `InputComponentBase`, `OverlayBase` — are this method's recurring convention. Keep them as the default naming; consult the project's bindings first, as its library may already use different names for the same roles.

## BaseComponent

All components inherit from `BaseComponent`. It provides:

- **Injected services:** the project's shared navigation, dialog/notification, and browser-interop services (see bindings for concrete names)
- **Common parameters:** `CssClass`, `Id`, `TestId`, `Loading`
- **CSS management:** `CssClasses` indexer with group-based class tracking
- **Location change handling:** `OnLocationChanging` virtual method
- **Disposable pattern:** built-in with `Dispose(bool disposing)` override

```csharp
public partial class MyComponent : BaseComponent
{
    protected override void OnParametersSet()
    {
        base.OnParametersSet(); // Clears all CSS classes — MUST be first

        AddCssClass(component, "my-base-class");
        AddCssClass(component, Variant.ToCssClass("my-prefix"));
        AddCssClass(component, Size.ToSizeCssClass("my-prefix"));
    }
}
```

**Critical:** `base.OnParametersSet()` clears all CSS classes via `CssClasses.Clear()`. You MUST re-add every class on every call.

## CSS class groups

Components define named groups for distinct visual sections, then reference them in markup:

```csharp
// Code-behind
private const string header = nameof(header);
private const string body = nameof(body);

protected override void OnParametersSet()
{
    base.OnParametersSet();

    AddCssClass(component, "card");
    AddCssClass(header, "card-header");
    AddCssClass(header, HeaderCssClass);
    AddCssClass(body, "card-body");
    AddCssClass(body, BodyCssClass);
}
```

```razor
@* Markup *@
<div class="@CssClasses[component]">
    <div class="@CssClasses[header]">...</div>
    <div class="@CssClasses[body]">@ChildContent</div>
</div>
```

**Rules:**

- `component` is always the root element's group (inherited constant from `BaseComponent`)
- Section groups only when the component has distinct visual sections (header, body, footer)
- Expose `{Section}CssClass` parameters so callers can add classes to sections
- Map enums to CSS directly: `Variant.ToCssClass("prefix")`, `Size.ToSizeCssClass("prefix")`

## Shared enums and extensions

```csharp
// Already defined — use these, don't recreate
public enum Variant { Default, Primary, Secondary, Success, Danger, Warning, Info, Purple, Light, Dark }
public enum Size { Default, ExtraSmall, Small, Medium, Large, ExtraLarge }
public enum Placement { Top, Bottom, Start, End }

// Extension methods for CSS mapping
Variant.ToCssClass("btn")       // → "btn-primary" (empty for Default)
Size.ToSizeCssClass("btn")      // → "btn-sm" (empty for Default)
Style.ToButtonStyleCss(Variant)  // → "btn-outline-primary"
```

**When to create a new enum:**

- **Shared:** Value is meaningful across 3+ components. Add to the project's shared enums file (see bindings).
- **Component-specific:** Value only makes sense for one component (e.g. a card border style, a dialog size, a tab style). Define in the component's `.razor.cs` file.

## Parameter design

1. **String/bool/enum** for common cases
2. **`RenderFragment`** for complex content that can't be a string
3. **`RenderFragment` overrides string** when both exist for the same section (e.g. `HeaderContent` overrides `Title`)
4. **`CssClass` always available** as escape hatch
5. **Section `CssClass` parameters** only for components with distinct visual sections
6. **`EventCallback`** for interactions — never `Action` or raw delegates
7. **`required`** only for parameters that make no sense without a value (e.g. a grid column's `Label`)

```csharp
// Good: string for simple, RenderFragment for complex, RenderFragment wins
[Parameter] public string? Title { get; set; }
[Parameter] public RenderFragment? HeaderContent { get; set; }  // overrides Title
[Parameter] public RenderFragment? ChildContent { get; set; }
[Parameter] public string? HeaderCssClass { get; set; }

// Bad: over-parameterized
[Parameter] public string? TitleIcon { get; set; }
[Parameter] public string? TitleIconPosition { get; set; }
[Parameter] public bool TitleBold { get; set; }
```

---

# Component taxonomy

The categories below describe the shape of a themed component library — the roster within each category is this project's, not a fixed catalogue. Read `.claude/bindings/blazor-component-author.md` for the concrete component and service names before starting work; without bindings, treat the illustrative names below as generic examples of the pattern, not a required inventory.

## Containers

Components that wrap and organise content — panels, dialogs, off-canvas panes, accordions, tabs, wizards, collapsibles, carousels, dropdowns, list groups, and similar. See this project's roster (bindings) for the concrete component names.

**Patterns:**

- Overlay containers (e.g. a dialog or off-canvas component) extend `OverlayBase` — shared show/hide, confirm-before-hide, section parameters, `OnHide` callback
- Collapsible containers use a boolean flag + CSS transitions for show/hide — no JS
- Containers with repeated children use the parent-child registration pattern (see Composability)
- Most expose `HeaderContent`, `FooterContent`, `ChildContent` slots plus string shortcuts (`Title`, `HeaderTitle`)

**OverlayBase contract:**

```csharp
public abstract class OverlayBase : BaseComponent
{
    // Shared parameters: Title, HeaderContent, FooterContent, ChildContent,
    //   ShowCloseButton, HeaderCssClass, BodyCssClass, FooterCssClass,
    //   ConfirmBeforeHide, ConfirmMessage, OnHide
    // Methods: Show(), Hide(), HideCoreAsync() (override for custom behaviour)
}
```

When building a new overlay component, inherit from `OverlayBase`. Don't reinvent show/hide.

## Inputs

Form components — text input, typed select, date picker, file input, tag input, OTP input, password-strength meter, range slider, and similar. See this project's roster (bindings) for the concrete component names.

**Patterns:**

- All inherit from `InputComponentBase` — which extends `BaseComponent` and implements `IInput`
- `InputComponentBase` handles: input-context registration/unregistration, `Size`, `IncludeInValidation`, `Validate()`, `ResetValidation()`, `ValidationMessage`, `ValidationCss`
- Every input must implement `Validate()` — run validation rules and set `ValidationMessage`
- Generic inputs (e.g. a typed `Select<TValue>`) use type parameters for type-safe binding
- Two-way binding: `Value`/`ValueChanged` pair, or `Values`/`ValuesChanged` for multi-select
- `Validations` parameter accepts `IEnumerable<ValidationRule<T>>` for declarative validation
- Size maps to input-specific CSS classes defined by the theme

**When building a new input:**

```csharp
public partial class MyInput : InputComponentBase
{
    [Parameter] public string? Value { get; set; }
    [Parameter] public EventCallback<string?> ValueChanged { get; set; }
    [Parameter] public IEnumerable<ValidationRule<string>> Validations { get; set; } = [];

    public override void Validate()
    {
        ValidationMessage = string.Empty;
        foreach (var rule in Validations)
        {
            if (!rule.IsValid(Value))
            {
                ValidationMessage = rule.Message;
                return;
            }
        }
    }
}
```

## Navigation

Route and menu components — nav menu, nav item, breadcrumb, pagination, and similar. See this project's roster (bindings) for the concrete component names.

**Patterns:**

- Hierarchical menu components use the parent-child registration pattern
- A pagination component is typically stateless — takes current page, total, page size as parameters and emits an `OnPageChanged` callback
- A route-aware breadcrumb component reads route metadata — no manual breadcrumb construction

## Notifications

Feedback components — alert, badge, progress/progress-step, toast/toast-container, tooltip, and similar. See this project's roster (bindings) for the concrete component names.

**Patterns:**

- A self-contained alert component handles its own dismiss capability
- Toast components are typically driven by the project's shared dialog/notification service — the service publishes, a container component listens and renders
- A tooltip component can be pure Blazor — positioned via CSS calculations in C#, no JS. May support both tooltip and popover modes
- Multi-step progress components use the parent-child registration pattern

## Data display

A data grid (e.g. `Grid<TItem>`) is typically the most complex component in the library. Record-based configuration.

**Patterns:**

- Columns, actions, and filters defined as records (e.g. `IReadOnlyList<GridColumn<TItem>>`, `IReadOnlyList<GridAction<TItem>>`, `IReadOnlyList<GridFilter<TItem>>` — names illustrative, see bindings for this project's actual types)
- Supports both `IEnumerable<TItem>` (static) and `IAsyncEnumerable<TItem>` (streaming with progressive loading)
- Pagination, search, sort, column toggle, export, print — controlled via an options flags enum
- Row selection with `SelectedItems`/`SelectedItemsChanged` two-way binding
- Expanded row template for detail views
- Row actions support both a handler callback (`OnSubmit`) and a navigation `Href`, with conditional visibility

## Services

Scoped services enable cross-component communication. A typical library has, at minimum:

- **A dialog/notification service** — event-driven: confirmations, alerts, input dialogs, panel requests, grid action flyouts. Components subscribe to events, the service publishes.
- **A browser-interop service** — centralised JS interop: clipboard, history, DOM attributes, scroll, focus, print. Lazy-loads a single ES module. All JS goes through here, never `IJSRuntime` directly.
- Whatever else the theme or project needs (e.g. theme switching, idle-session detection).

See this project's roster (bindings) for the concrete service names.

---

# Composability patterns

## 1. Parent-child registration

Used when a parent manages an ordered collection of children — e.g. a wizard and its steps, an accordion and its items, tabs and their panels, a multi-step progress bar and its steps (names below illustrative — see bindings for this project's actual components).

**Parent side:**

```csharp
public partial class Wizard
{
    internal List<WizardStep> Steps { get; } = [];

    internal void RegisterStep(WizardStep step)
    {
        if (!Steps.Contains(step))
        {
            Steps.Add(step);
            StateHasChanged();
        }
    }

    internal void UnregisterStep(WizardStep step)
    {
        Steps.Remove(step);
        StateHasChanged();
    }
}
```

**Child side:**

```csharp
public partial class WizardStep
{
    [CascadingParameter] public Wizard? ParentWizard { get; set; }

    protected override void OnInitialized()
    {
        ParentWizard?.RegisterStep(this);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
            ParentWizard?.UnregisterStep(this);
        base.Dispose(disposing);
    }
}
```

**Rules:**

- Child finds parent via `[CascadingParameter]`
- Register in `OnInitialized`, unregister in `Dispose`
- Parent calls `StateHasChanged()` after registration changes
- Parent's `ChildContent` renders children; children render their own content conditionally based on parent state (e.g. active tab)
- Registration methods are `internal` — not part of the public API

## 2. Cascading context

Used when a container provides shared state to arbitrary descendants — e.g. a shared input-validation context (`InputContext` in this method's convention; see bindings for this project's name).

```razor
@* InputContext cascades itself to all descendant IInput components *@
<InputContext>
    <Input Label="Name" ... />
    <Select Label="Role" ... />
    <Button OnClick="Submit" />  @* Can call InputContext.ValidateInputs() *@
</InputContext>
```

**How it works:**

- `InputContext` renders as a `<CascadingValue>` of itself
- `InputComponentBase.OnInitialized` registers with the cascaded `InputContext`
- `InputComponentBase.Dispose` unregisters
- `InputContext.ValidateInputs()` iterates all registered inputs, calls `Validate()` on each, returns aggregate result

**When to use:** When unrelated components at varying nesting depths need shared state from a common ancestor. Don't use for direct parent-child relationships — use registration pattern instead.

## 3. Slot-based composition (RenderFragment)

The primary composition mechanism. Components define named slots that callers fill:

```csharp
[Parameter] public RenderFragment? HeaderContent { get; set; }
[Parameter] public RenderFragment? FooterContent { get; set; }
[Parameter] public RenderFragment? ChildContent { get; set; }
```

**Typed slots** for templated components:

```csharp
[Parameter] public RenderFragment<TItem>? ExpandedRowTemplate { get; set; }
```

**Override hierarchy:** When both a string shortcut and a `RenderFragment` exist for the same section, the `RenderFragment` wins:

```razor
@if (HeaderContent != null)
{
    @HeaderContent
}
else if (!string.IsNullOrEmpty(Title))
{
    <h4 class="card-title">@Title</h4>
}
```

## 4. Record-based configuration

Used for components configured with structured data rather than child components — e.g. a data grid (`Grid<TItem>`).

```csharp
// Caller builds configuration as records
var columns = new GridColumn<User>[]
{
    new() { Label = "Name", Accessor = u => u.Name },
    new() { Label = "Email", Accessor = u => u.Email, Sortable = false },
};

var actions = new GridAction<User>[]
{
    new() { Label = "Edit", Icon = "ti ti-edit", OnSubmit = EditUser },
    new() { Label = "Delete", Variant = Variant.Danger, OnSubmit = DeleteUser },
};
```

**When to use:** When configuration is tabular/repetitive and defining child components would be verbose. Records give strong typing and can be built dynamically.

**When NOT to use:** When children need their own `RenderFragment` content (use parent-child registration instead).

## 5. Service-based communication

Used for cross-cutting concerns that span the component tree — e.g. a shared dialog/notification service (`DialogService` in this method's convention; see bindings for this project's name).

```csharp
// Any component can trigger a dialog
DialogService.ShowConfirmation("Delete?", "This cannot be undone.", async () => await Delete());

// The app's root shell layout listens and renders the dialog
DialogService.OnDialogTriggered += (_, content) => { ... };
```

**When to use:** For application-level UI (toasts, confirmations, alerts) where the trigger and the renderer are in completely different parts of the tree.

**Rules:**

- Services are scoped (per-circuit in Blazor Server)
- Use events (`EventHandler<T>`) for pub/sub
- Renderer components (e.g. a toast container, a confirmation dialog) live in the app's root shell layout and subscribe to service events
- Triggering components call service methods directly

---

# Implementation workflow

## Step 1: Analyze

Before writing code:

1. **Study the theme** — find all pages that use the element, catalogue every visual variation
2. **Read existing components** — check if a base class, shared enum, or pattern already covers part of what you need
3. **Decide the composability pattern** — parent-child? cascading? record-based? Just slots?
4. **Check browser-native options** — can CSS or HTML elements handle the behaviour without C# state?

## Step 2: Design the API

Write the parameter list before implementation. Validate it mentally against every theme variation:

```csharp
// Proposed API:
// - Parameters: Value, OnValueChanged, Variant, Size, Disabled, Placeholder
// - Slots: ChildContent, HeaderContent
// - CSS: CssClass, HeaderCssClass
// Composability: InputComponentBase (registers with InputContext)
// Behavior: CSS transitions for expand/collapse, no JS
```

**Ask yourself:**

- Can this API produce every theme variation?
- Is any parameter only used in one niche scenario? (Drop it — use `RenderFragment`)
- Am I under the parameter budget?
- Does this duplicate functionality from an existing component?

## Step 3: Implement

**File structure:**

```
ComponentName.razor       — Markup only
ComponentName.razor.cs    — Parameters, logic, OnParametersSet
ComponentName.razor.css   — Scoped styles (only if theme CSS needs minor glue — rare)
```

**Implementation order:**

1. Choose base class (`BaseComponent`, `InputComponentBase`, `OverlayBase`)
2. Define parameters and any component-specific enums
3. `OnParametersSet` — CSS class mapping using groups
4. Razor markup — match theme HTML structure exactly
5. Event handling and state management
6. Composability wiring (registration, cascading, etc.)
7. `Dispose` cleanup if needed

## Step 4: Build and verify

```bash
dotnet build
```

Zero errors. Then verify:

- [ ] Component renders the correct theme HTML for every supported variation
- [ ] Re-renders produce correct output (toggle parameters, check CSS classes rebuild)
- [ ] Disposal cleans up resources (unregister from parent, dispose timers)
- [ ] `TestId` is applied to the root element
- [ ] No JS interop unless accessing a browser API with no alternative

---

# Anti-patterns

## Never do these

| Anti-pattern                                             | Do instead                                                       |
| ---------------------------------------------------------| ------------------------------------------------------------------|
| Call `IJSRuntime` directly                                | Use the project's shared browser-interop service (see bindings)  |
| Invent CSS classes not in the theme                       | Use only theme classes                                            |
| Skip `base.OnParametersSet()`                              | Always call it first — it clears CSS                              |
| Store state in DOM (data attributes, JS globals)           | Keep all state in C# properties                                   |
| Use `Action`/`Func` for callbacks from callers              | Use `EventCallback` / `EventCallback<T>`                          |
| Add `_` prefix to private fields                            | Use plain camelCase: `isVisible`, `activeIndex`                   |
| Over-parameterize (30+ parameters)                          | Use `RenderFragment` for complex/rare cases                       |
| Build JS workarounds for CSS-solvable problems               | Use CSS transitions, `:focus-within`, native HTML                 |
| Create a component-specific enum when a shared one fits       | Check the project's shared enums file first (see bindings)        |
| Register in `OnParametersSet` (runs many times)               | Register in `OnInitialized` (runs once)                           |
| Forget to unregister in `Dispose`                              | Always unregister what you registered                             |
| Use `OnAfterRenderAsync` for state that affects markup          | Use `OnParametersSet` — render once, not twice                    |
