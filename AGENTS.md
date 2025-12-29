# Swift Code Style Guidelines

## Purpose
Agents act as senior Swift collaborators. Keep responses concise,
clarify uncertainty before coding, and align suggestions with the rules linked below.

## Core Style
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Language**: Using English as the primary language
- **Dependency**: Use dependency injection for all services and environment values to keep code testable

## File Organization
- Logical directory grouping
- PascalCase files for types, `+` for extensions
- Modular design with extensions

## Modern Swift Features
- **@Observable macro**: Replace `ObservableObject`/`@Published`
- **Swift concurrency**: `async/await`, `Task`, `actor`, `@MainActor`
- **Result builders**: Declarative APIs
- **Property wrappers**: Use line breaks for long declarations
- **Opaque types**: `some` for protocol returns

## Code Structure
- Early returns to reduce nesting
- Guard statements for optional unwrapping
- Single responsibility per type/extension
- Value types over reference types

## Error Handling
- `Result` enum for typed errors
- `throws`/`try` for propagation
- Optional chaining with `guard let`/`if let`
- Typed error definitions

## Architecture
- Protocol-oriented design
- Dependency injection over singletons
- Composition over inheritance
- Factory/Repository patterns

## Debug Assertions
- Use `assert()` for development-time invariant checking
- Use `assertionFailure()` for unreachable code paths
- Assertions removed in release builds for performance
- Precondition checking with `precondition()` for fatal errors

## Memory Management
- `weak` references for cycles
- `unowned` when guaranteed non-nil
- Capture lists in closures
- `deinit` for cleanup

## Build
xcodebuild -workspace ABPlayer.xcworkspace -scheme ABPlayer -destination 'platform=macOS' build 2>&1 | tail -20

## Workflow
- Ask for clarification when requirements are ambiguous; surface 2–3 options when trade-offs matter

## Gemini Added Memories
- When the user says 'quick commit', generate a commit message for staged changes by examining git status, git diff --staged, and git log -n 3. The commit message should follow the 'type(scope): message' format. Then, commit the changes using the generated message.