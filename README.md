# cds-typer + tsx + @cap-js/attachments — Circular Dependency Bug

## Summary

When `@cap-js/attachments` is used in a CAP TypeScript project running under `cds-tsx watch`, the server fails to start with:

```
TypeError: Class extends value undefined is not a constructor or null
```

## Versions Tested

| Package | Version |
|---------|---------|
| `@sap/cds` | 9.8.x |
| `@cap-js/cds-typer` | 0.38.0 |
| `@cap-js/attachments` | 3.9.0 |
| `@cap-js/sqlite` | 2.x |
| `tsx` | 4.x |
| Node.js | 22.x |

## Steps to Reproduce

```bash
npm install
npm run dev
```

The server crashes immediately after model loading with `TypeError: Class extends value undefined is not a constructor or null`.

## Fix

Use the shorter path mapping in `tsconfig.json` (per [cap-js/cds-typer#381](https://github.com/cap-js/cds-typer/issues/381)):

```diff
- "#cds-models/*": ["./@cds-models/*/index.ts"]
+ "#cds-models/*": ["./@cds-models/*"]
```

Then run `npm run dev` again — the server starts correctly.

Alternatively, deleting all `.js` files from `@cds-models/` also works:

```bash
npm run dev:workaround
```

## Root Cause

`@cap-js/cds-typer` generates **both** `.js` and `.ts` files for every module in `@cds-models/`. When running under `tsx` (which registers as a CJS loader), Node's CJS module resolver prefers `.js` over `.ts` for the same module.

The `@cap-js/attachments` plugin introduces a **circular import chain** in the generated types:

1. `@cds-models/index.ts` imports `./sap/attachments` (the plugin declares a root-level `aspect Attachments`)
2. `@cds-models/sap/attachments/index.ts` imports `./../../` back (it needs `_cuidAspect`, `_managedAspect`)
3. During this circular resolution, `import * as __ from './_'` in the root file resolves to `_/index.js` (the `.js` file) instead of `_/index.ts`
4. The `.js` file for `_/` intentionally does **not** export the `Entity` base class (it's a TypeScript-only mock class used for typing, replaced at runtime by `createEntityProxy`)
5. `__.Entity` is `undefined` → `class cuid extends _cuidAspect(__.Entity)` fails

**Without `@cap-js/attachments`**, there is no `sap/attachments` directory and no circular import, so the bug does not manifest.

The explicit `*/index.ts` path mapping forces tsx to resolve the exact file, hitting the `.js` shadow during circular resolution. The shorter `*` path lets tsx resolve the module more flexibly, avoiding the `.js` file.

### Why the `.js` file doesn't have `Entity`

This is by design in cds-typer. The `_/index.js` file exports `createEntityProxy` for runtime entity construction, while the `Entity` class (a TypeScript mock with `declare` properties) only exists in the `.ts` output. This works correctly in compiled projects (where `.ts` files are compiled to `.js` and the originals are gone), but breaks under `tsx` where both `.js` and `.ts` coexist and CJS resolution picks `.js`.

### Where in cds-typer source

- `node_modules/@cap-js/cds-typer/lib/file.js` line ~833: The `writeout()` method **unconditionally** generates both `.js` and `.ts` files (hardcoded `Promise.all`). There is no config option to skip `.js` generation.
- The `outputDTsFiles` option only controls `.ts` vs `.d.ts` naming for the TypeScript output; `.js` is always written regardless.

## Suggested Fix

`@cap-js/cds-typer` should either:

1. **Not generate `.js` files when `.ts` files are generated** — since `tsx`/`ts-node` can consume `.ts` directly, the `.js` files are redundant and cause resolution conflicts.
2. **Or ensure `.js` files export the same symbols as `.ts` files** — including the `Entity` class (even if as a no-op base).
3. **Or provide a config option** (e.g., `typer.jsOutput: false`) to opt out of `.js` file generation.
