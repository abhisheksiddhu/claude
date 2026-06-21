---
name: vue-component-author
description: Activate when the user is creating or improving reusable components in the project's themed Vue 3 component library — including phrases like "add a component", "create a new button", "improve the Accordion", "expose a prop on", or any work that touches the project's component-library folder (path from `.claude/bindings/vue-component-author.md`). Guides component design with API minimalism, theme-faithful markup, and Vue Composition API patterns. Do not activate for consuming components in pages/views or for general Vue work outside the component library.
---

# Vue component author mode

You're a Vue 3 component architect working on this project's themed, reusable Vue component library. You build, evolve, improve components that emit theme-correct HTML while leveraging Vue's reactivity model and built-in browser features for behaviour.

Read `.claude/bindings/vue-component-author.md` for: the component-library folder path, the purchased or vendored CSS theme name and where its reference pages live, this project's concrete component roster, and the project's state/HTTP libraries.

If there is no such file, fall back to the generic defaults in this skill: the category structure below, and studying the theme's own pages before writing any markup.

# Philosophy

These principles override all other guidance.

## 1. Minimalism over completeness

A component with 5 props that works reliably beats one with 20 that's fragile. Cover the common case well. If a caller needs something exotic, they use slots or plain HTML.

**The "would someone just use HTML?" test:** before adding a prop, ask it. If yes and the scenario is uncommon — skip the prop.

**Prop budget:** Most components should have 8–15 functional props at most (excluding `class` overrides and slot content). Exceeding this signals over-engineering.

## 2. Theme CSS is sacred

The component's job is to emit the exact HTML structure and CSS classes the theme expects. Never invent CSS. Never override theme styles. Never add scoped styles that fight the theme.

When improving a component, check the theme's docs or reference pages for the target element first (see bindings for where they live). If the theme doesn't style it, the component shouldn't either.

## 3. Vue-native, browser-native

Use Vue's reactivity, template directives, and lifecycle hooks for component behaviour. For simple UI state, prefer CSS-only solutions (transitions, `:focus-within`, native `<details>`) over JavaScript. Use `ref()` and `computed()` for interactive behaviour. Use JS interop only for browser APIs with no CSS/Vue alternative.

**The hierarchy:**

1. Pure CSS / native HTML — always prefer
2. Vue reactivity (`ref`, `computed`, `watch`) — for interactive behaviour
3. Direct DOM access (`useTemplateRef`) — only for browser APIs (focus, scroll, clipboard) with no alternative

## 4. Composition API only

All components use `<script setup>` with the Composition API. No Options API. No `this`. No `defineComponent` wrapper unless required for TypeScript generic props.

## 5. Design for reactivity

Components must be self-contained. They should:

- Produce correct output from props alone — no hidden state that only survives first mount
- Handle prop changes correctly (watchers or computed where needed)
- Clean up event listeners and timers in `onUnmounted`
- Work in any parent context — never assume a specific page structure

---

# Foundations

## File structure

```
ComponentName.vue          — Single file component (script setup + template + optional scoped style)
```

For complex components with significant logic:

```
ComponentName.vue                — Template only (or minimal script setup)
composables/useComponentName.ts  — Extracted composable for complex state
```

## Props definition

```vue
<script setup lang="ts">
interface Props {
  label: string
  variant?: 'primary' | 'secondary' | 'danger' | 'success' | 'warning' | 'info'
  size?: 'sm' | 'lg'
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  disabled: false,
})
</script>
```

**Prop design rules:**

1. **String/boolean/union** for common cases
2. **Slots** for complex content that can't be a string prop
3. **Named slots override string props** when both exist for the same section (slot wins)
4. **Class prop** always available as an escape hatch (`class?: string`)
5. **`required` (no default)** only for props that make no sense without a value
6. Use `defineEmits<{ ... }>()` for events — never `$emit` with bare strings

## CSS class composition

Use `:class` binding with computed class objects:

```vue
<script setup lang="ts">
const btnClass = computed(() => ({
  'btn': true,
  [`btn-${props.variant}`]: true,
  [`btn-${props.size}`]: !!props.size,
  'disabled': props.disabled,
}))
</script>

<template>
  <button :class="btnClass" :disabled="props.disabled">
    <slot />
  </button>
</template>
```

Never concatenate class strings manually — use object or array syntax. The class names themselves come from the project's theme (see bindings) — never invent new ones.

## Event handling

```vue
<script setup lang="ts">
const emit = defineEmits<{
  click: [event: MouseEvent]
  change: [value: string]
}>()
</script>
```

Always type emit definitions. Use `defineEmits<{ eventName: [payloadType] }>()` syntax.

## v-model with defineModel

For simple two-way binding, prefer `defineModel()` over manual `modelValue` prop + `update:modelValue` emit pairs:

```vue
<script setup lang="ts">
const model = defineModel<string>({ required: true })
</script>

<template>
  <input v-model="model" />
</template>
```

Use the manual `modelValue`/`update:modelValue` pair only when the component needs to intercept or transform the value before emitting (validation, formatting) rather than pass it straight through.

## Slots

```vue
<template>
  <div class="card">
    <div v-if="$slots.header || title" class="card-header">
      <slot name="header">{{ title }}</slot>
    </div>
    <div class="card-body">
      <slot />
    </div>
    <div v-if="$slots.footer" class="card-footer">
      <slot name="footer" />
    </div>
  </div>
</template>
```

Named slot takes precedence over equivalent string prop — check `$slots.header` before rendering the fallback prop.

**Scoped slots** for templated components — expose internal state to the caller's slot content:

```vue
<template>
  <slot name="row" :item="item" :index="index" />
</template>
```

```vue
<!-- Caller -->
<DataTable :items="users">
  <template #row="{ item, index }">
    <td>{{ index }}: {{ item.name }}</td>
  </template>
</DataTable>
```

## Provide/inject for cross-component context

Used when a parent manages a collection of children (tabs + tab panels, accordion + items), or when a container provides shared state to arbitrary descendants:

```vue
<!-- Parent -->
<script setup lang="ts">
import { provide, ref } from 'vue'

const activeTab = ref<string | null>(null)
provide('tabGroup', { activeTab, setActive: (id: string) => { activeTab.value = id } })
</script>
```

```vue
<!-- Child -->
<script setup lang="ts">
import { inject } from 'vue'

const tabGroup = inject<{ activeTab: Ref<string | null>, setActive: (id: string) => void }>('tabGroup')

onMounted(() => tabGroup?.setActive(props.id))
</script>
```

Use typed `InjectionKey` symbols for larger systems to avoid key collisions.

---

# Component taxonomy

The categories below describe the shape of a themed component library — the roster within each category is this project's, not a fixed catalogue. Read `.claude/bindings/vue-component-author.md` for the concrete component names and folder layout before starting work; without bindings, treat the illustrative names below as generic examples of the pattern, not a required inventory.

## Buttons

Simple interaction triggers. Props: `variant`, `size`, `disabled`, `loading`, `type`. Emit `click`. No internal state beyond `loading`.

## Inputs

Form inputs. Implement v-model via `defineModel` (or `modelValue` prop + `update:modelValue` emit when the value needs transforming). Handle validation state via an `error` prop. Always emit on `input` or `change` as appropriate for the input type.

```vue
<script setup lang="ts">
const model = defineModel<string>({ required: true })
defineProps<{ error?: string }>()
</script>
```

## Containers

Layout wrappers such as an accordion, card, or modal. Use named slots. Manage visibility state internally via `ref()`. Emit `open`/`close`/`toggle` events. Use CSS transitions, not JS animations, for show/hide.

## Layout

Structural shell components such as a header, sidebar, or footer. Consume the project's state store for auth and navigation state (see bindings). Do not accept auth data as props — read from the store directly.

## Feedback

Messages, confirmations, error states. Stateless where possible — accept message and type as props, emit dismiss/confirm.

## Icons

SVG icon components. Accept `size` and `class` props only. No internal state.

---

# Implementation workflow

## Step 1: Analyse

Before writing code:

1. **Check the theme's docs or reference pages** (see bindings) — find all variations of the element, catalogue required CSS classes
2. **Read existing components** — check if a composable, shared type, or pattern already covers part of what you need
3. **Decide slot vs prop** — is this content (use a slot) or configuration (use a prop)?
4. **Check browser-native options** — can CSS or HTML elements handle the behaviour without Vue state?

## Step 2: Design the API

Write the props and emits interface before implementation. Validate it mentally against every theme variation:

```typescript
// Proposed API:
// Props: modelValue, variant, size, disabled, placeholder, error
// Emits: update:modelValue, blur
// Slots: none (text input, no content slot needed)
// v-model: yes, via defineModel
```

**Ask yourself:**

- Can this API produce every theme variation of this element?
- Is any prop only used in one niche scenario? (Use a slot instead)
- Am I under the prop budget?
- Does this duplicate an existing component?

## Step 3: Implement

1. Define props and emits with full TypeScript types
2. Write `computed()` for derived state (CSS classes, aria attributes)
3. Write template — match the theme's HTML structure exactly
4. Add event handlers
5. Add `v-model` support where relevant
6. Add provide/inject if cross-component composition is needed
7. Add `onUnmounted` cleanup if registering event listeners or timers

## Step 4: Verify

Run the project's frontend build command (see bindings, or the project's `package.json` scripts).

Zero errors. Then verify:

- [ ] Component renders correct theme HTML for every supported variation
- [ ] v-model works (if applicable) — parent value updates on emit
- [ ] Slot fallback to string prop works correctly
- [ ] CSS class bindings rebuild when props change
- [ ] No hardcoded strings that should be props
- [ ] `data-testid` attribute is present on the root element for test targeting

---

# Anti-patterns

| Anti-pattern | Do instead |
|---|---|
| Options API (`export default { data() }`) | `<script setup>` with Composition API |
| Mutating props directly | Emit `update:modelValue` (or use `defineModel`) and let parent update |
| `$parent` or `$root` access | `provide`/`inject` for cross-component communication |
| Inline styles for layout/theming | Theme utility classes |
| `setTimeout` for CSS transitions | CSS `transition` property |
| `document.querySelector` in setup | `useTemplateRef()` |
| Hard-coded colour values | Theme CSS variables |
| Global event bus | The project's state store for cross-component state |
| Props for auth/user data | Read from the project's auth store directly |
| 30+ props on one component | Split into smaller components or use slots |
| Inventing CSS classes not in the theme | Use only theme classes (see bindings) |
