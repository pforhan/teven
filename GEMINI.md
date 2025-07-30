
# Gemini Code-Gen Assistant Guidelines

This document outlines the conventions and best practices to follow when using the Gemini code-generation assistant for the Teven project. Adhering to these guidelines will ensure consistency, maintainability, and high-quality code.

## General Principles

- **Follow Existing Conventions:** Before generating or modifying code, always analyze the surrounding files to understand and adopt the existing coding style, formatting, and architectural patterns.
- **Modular Architecture:** The backend is designed with a modular structure. Ensure that new code is placed in the appropriate module (`app`, `core`, `data`, `service`, `api`, `auth`).
- **2-Space Indentation:** Use 2 spaces for indentation in all code files.

## Backend (Kotlin/Ktor)

- **Import Wildcards:** Always expand import wildcards (`.*`) for clarity and to avoid potential conflicts.
- **Ktor and Exposed:** The backend uses Ktor for the web framework and Exposed for database access. All generated code should be compatible with these technologies.
- **Coroutines for Asynchronicity:** Use Kotlin Coroutines for all asynchronous operations to maintain a non-blocking architecture.
- **Dependency Injection:** Use Koin for dependency injection to manage component lifecycles and dependencies.
- **Testing:**
  - **Unit Tests:** All new business logic in the `service` module should be accompanied by unit tests. Use JUnit 5 and MockK for mocking dependencies.
  - **Integration Tests:** For new API endpoints, add integration tests to verify the entire request/response flow, including database interactions.

## Frontend (React/TypeScript)

- **Component-Based Architecture:** Follow a component-based architecture, creating reusable components where possible.
- **TypeScript:** Use TypeScript for all frontend code to ensure type safety.
- **State Management:** Use a consistent state management library (e.g., Redux, MobX) if one is established in the project.
- **Styling:** Follow the existing styling conventions (e.g., CSS-in-JS, CSS Modules).
- **API Interaction:** Use the API service classes in `src/api` to interact with the backend.

## Workflow

1.  **Understand the Goal:** Before generating code, make sure you understand the requirements from the PRD and the existing design from the `BACKEND-DESIGN.md` and `API.md` documents.
2.  **Generate Code:** Generate code that adheres to the principles and conventions outlined in this document.
3.  **Generate Tests:** After generating the primary code, generate the corresponding unit and/or integration tests.
4.  **Review and Refine:** Review the generated code and tests to ensure they are correct, efficient, and follow project standards.
