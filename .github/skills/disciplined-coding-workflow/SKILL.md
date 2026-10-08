---
name: disciplined-coding-workflow
description: 'Use for debugging, implementing, reviewing, or refactoring code when you need a disciplined evidence-first workflow: identify the controlling code path, form a falsifiable hypothesis, make a minimal edit, run focused validation, and finish with verified results.'
argument-hint: 'Describe the behavior, failing check, or code surface to investigate.'
user-invocable: true
---

# Disciplined Coding Workflow

Use this skill to move from an observed behavior to a verified code change without broad, speculative exploration.

## When to Use

- Debugging a failing test, error, or unexpected behavior
- Implementing a focused feature or behavior change
- Reviewing a change for regressions and missing validation
- Refactoring a local code path while preserving its contract

## Procedure

1. **Identify the concrete anchor.** Start from the named file, symbol, failing command, test, user-visible behavior, or nearest implementation surface. Search only enough to locate the code that directly computes, mutates, or controls the behavior.
2. **Inspect local evidence.** Read the owning implementation and one nearby test, call site, or analogous implementation. Avoid mapping unrelated parts of the repository.
3. **State a falsifiable hypothesis.** Describe the likely cause or intended control flow in one sentence. Name one cheap check that could disconfirm it.
4. **Choose the smallest testable change.** Preserve existing APIs and conventions. Prefer a reversible, local edit that directly exercises the hypothesis. Do not fix unrelated issues.
5. **Edit deliberately.** Keep the patch focused. Avoid unrelated formatting, metadata churn, and comments that merely narrate obvious code.
6. **Validate immediately.** After the first substantive edit, run the narrowest available behavior test, focused test, compile/typecheck, or lint command. Do not resume broad exploration before this check.
7. **Interpret the result.**
   - If validation succeeds, make only the next adjacent edit required by the task, then rerun focused validation.
   - If it fails while supporting the hypothesis, repair the same slice and rerun the same check.
   - If it falsifies the hypothesis, take one nearby hop toward the more direct controller and revise the hypothesis.
   - If it is ambiguous, inspect one nearby boundary or call site, then choose between local repair and the one-hop revision.
8. **Complete the task.** Confirm the requested behavior, run at least one post-edit executable check when available, and report changed files, validation performed, and any remaining test gap or blocker.

## Decision Rules

- Stop searching once you can name the controlling path, a falsifiable hypothesis, a discriminating check, and a small edit.
- Prefer existing abstractions, helpers, libraries, and test patterns over new machinery.
- Keep validation proportional to blast radius: narrow for local changes; broader for shared contracts or user-facing workflows.
- Never discard unrelated user changes. Work with them unless they make the task impossible.
- Do not claim success without executable validation or, when commands are unavailable, an explicit explanation of the limitation.

## Completion Checklist

- [ ] The behavior-owning code path was identified.
- [ ] A falsifiable hypothesis and discriminating check were established.
- [ ] The change is minimal and scoped to the request.
- [ ] Focused validation was run after editing.
- [ ] The final result and any residual risk are stated clearly.
