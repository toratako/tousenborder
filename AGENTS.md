# AGENTS.md

## Project Rules

- UIに無駄な説明を足さない
- ドキュメントは後続のAgentの理解を助けるために書く (正本はコードなので冗長に書かない)
- ドキュメントはハマりポイントと，軽いRouting Index程度

---

## Preferences

- Read relevant implementation, tests, and nearby examples before editing.
- Keep changes within the requested scope. Preserve unrelated work, existing interfaces, architecture, and dependencies unless the task requires changing them.
- Treat repository source code, tests, lockfiles, and local documentation as primary evidence. Prefer established local patterns over introducing new ones.
- Prefer the simplest design that fully satisfies the task and repository conventions.
- Do not introduce misleading placeholders, stubs, or TODOs to make incomplete work appear complete.
- Run checks that cover the changed behavior and any required repository checks. Start targeted and broaden only for new changes, failures, cross-cutting effects, or unresolved concerns; avoid tests that merely restate a trivial edit.
- Before completion, review the diff for unintended changes, duplicate logic, dead code, regressions, and missing tests.
