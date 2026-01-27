# [Task/Feature Name] Specification

> **Status**: DRAFT | FINALIZED
> **Owner**: User | Agent
> **Dates**: YYYY-MM-DD

---

## 🎯 Objective
*Start with a high-level vision. What are we building and why?*
*(Example: "Build a web app for small teams to manage tasks...")*

## 🏗️ Tech Stack
*Be specific about versions and tools.*
- **Framework**: [e.g. React 18+, TypeScript, Vite]
- **Backend**: [e.g. Node.js/Express, Python/FastAPI]
- **Database**: [e.g. PostgreSQL, Prisma ORM]
- **Styling**: [e.g. Tailwind CSS]

## 💻 Agent Commands
*Executable commands the agent should use.*
- **Build**: `[e.g. npm run build]`
- **Test**: `[e.g. npm test]`
- **Lint**: `[e.g. npm run lint --fix]`
- **Run**: `[e.g. npm run dev]`

## �️ Agent Safety & Environment
*Recommended environment for "autonomous" or "high-permission" agents.*
- **Sandbox**: Use the provided `Vagrantfile` to run agents in an isolated VM.
- **Permissions**:
    - `sudo` is widely available in the VM.
    - Host filesystem is synced to `/agent-workspace`.
    - **Caution**: `rm -rf` in `/agent-workspace` deletes files on the host!

## �📂 Project Structure
*Key directories and their purpose.*
- `src/`: Application source code
- `tests/`: Unit and integration tests
- `docs/`: Documentation
- `Vagrantfile`: Configuration for safe agent execution VM.

## 🧱 Boundaries & Constraints
### ✅ Always (Do without asking)
- Run tests before commits.
- Follow naming conventions.
- [Add others]

### ⚠️ Ask First (Seek approval)
- Database schema changes.
- Adding new dependencies.
- [Add others]

### 🚫 Never (Hard stop)
- Commit secrets (API keys, credentials).
- Edit `node_modules/` or vendor files directly.
- [Add others]

## 📋 Requirements
### Functional
- [ ] Requirement 1
- [ ] Requirement 2

### Non-Functional
- [ ] Performance constraints
- [ ] Security constraints

## 🧪 Verification Plan
*How will you prove it works?*
### Automated
- [ ] Run `npm test` and ensure all pass.

### Manual
- [ ] UI Check: [Description]
- [ ] Screenshot: [Description]
