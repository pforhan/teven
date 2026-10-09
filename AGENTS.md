
# LLM Agent Guidelines

This document outlines the conventions and best practices to follow when using LLM Agents for the Teven project. Adhering to these guidelines will ensure consistency, maintainability, and high-quality code.

## General Principles

- **Follow Existing Conventions:** Before generating or modifying code, always analyze the surrounding files to understand and adopt the existing coding style, formatting, and architectural patterns.
- **Modular Architecture:** The backend is designed with a modular structure. Ensure that new code is placed in the appropriate module (`app`, `core`, `data`, `service`, `api`, `auth`).
- **2-Space Indentation:** Use 2 spaces for indentation in all code files.
- **Confirmation of changes:** Always run the build and tests to confirm any changes.
- **Do not check in code:** Unless specifically instructed to do so, don't set up any git commands.

## Backend (Kotlin/Ktor)

- **Building:** Build and test backend with `gradlew :backend:app:assemble`
- **Import Wildcards:** Always expand import wildcards (`.*`) for clarity and to avoid potential conflicts.
- **Trailing Commas:** Always use trailing commas where possible, for parameters, enums, etc.
- **Named Parameters:** Any time there's more than one parameter or there's any chance for confusion, use named parameters in method calls.
- **Expression Bodies:** For simple methods consisting only of a return statement, write the method instead as an expression body. 
- **Ktor and Exposed:** The backend uses Ktor for the web framework and Exposed for database access. All generated code should be compatible with these technologies.
- **Coroutines for Asynchronicity:** Use Kotlin Coroutines for all asynchronous operations to maintain a non-blocking architecture.
- **Dependency Injection:** Use Koin for dependency injection to manage component lifecycles and dependencies.
- **Testing:**
  - **Unit Tests:** All new business logic in the `service` module should be accompanied by unit tests. Use JUnit 5 and MockK for mocking dependencies.
  - **Integration Tests:** For new API endpoints, add integration tests to verify the entire request/response flow, including database interactions.

## Frontend (React/TypeScript)

- **Building:** Build and test frontend with `npm run build --prefix frontend`
- **Component-Based Architecture:** Follow a component-based architecture, creating reusable components where possible.
- **TypeScript:** Use TypeScript for all frontend code to ensure type safety.
- **State Management:** Use a consistent state management library (e.g., Redux, MobX) if one is established in the project.
- **Styling:** Follow the existing styling conventions (e.g., CSS-in-JS, CSS Modules).
- **API Interaction:** Use the API service classes in `src/api` to interact with the backend.

## Commits

**No commit-message tooling is configured.** There is no husky, commitlint, or
lint-staged in this repo, and none should be added — there is no hook to
satisfy and no format to enforce. Write commit messages the way the existing
history does.

- **Subject line:** a short, lowercase, descriptive phrase in the imperative or
  plain-noun style the history already uses — `port data model over to
  flutter`, `keep selected organization when going to events list`. A
  conventional-commit prefix (`feat(flutter):`, `fix(flutter):`) is *optional
  and inconsistent here*: of the last ~20 commits, most have no prefix. Use one
  when it genuinely helps, not because a linter would demand it. Keep it under
  ~72 characters.
- **Body:** use it only when the *what* and *why* do not fit the subject. Two
  habits from this repo's history are worth keeping:
  - **Reference conversion tasks when relevant**, e.g. `(tasks 1.9-1.13)` or
    `(Phase 0, tasks 0.9-0.11)`. `FLUTTER-CONVERT.md` is the source of truth
    for what was done and why.
  - **Do not restate rationale that is already written down.** If the reasoning,
    trade-offs, or measurements live in `FLUTTER-CONVERT.md`, a summary
    pointing at them beats a duplicate that will drift.
- **Footer:** end agent-authored commits with `opencode/bunny` on its own line.
- **Never `git add -A`** — this repo has a history of stray files being picked up. Stage deliberately with `git add <path>`.
- **Generated code is not committed.** `flutter_app/.gitignore` excludes `*.freezed.dart` and `*.g.dart` from `build_runner`. Confirm none are staged, and note that this means **`dart run build_runner build` is a required step after every fresh clone** — without it `flutter analyze` reports unresolved constructors and `flutter run` will not compile.
- **Do not commit unless asked.** See "Do not check in code" above; committing is a separate, explicit instruction.

1.  **Understand the Goal:** Before generating code, make sure you understand the requirements from the PRD and the existing design from the `BACKEND-DESIGN.md` and `API.md` documents.
2.  **Generate Code:** Generate code that adheres to the principles and conventions outlined in this document.
3.  **Generate Tests:** After generating the primary code, generate the corresponding unit and/or integration tests.
4.  **Review and Refine:** Review the generated code and tests to ensure they are correct, efficient, and follow project standards.
