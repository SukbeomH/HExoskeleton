# Task Sizing Reference

## Context Budget Rules

- **Small task:** <10% context budget, 1-2 files, local scope
- **Medium task:** 10-20% budget, 3-5 files, single subsystem
- **Large task (SPLIT THIS):** >20% budget, many files, crosses boundaries

---

## Split Signals

Split into multiple plans when:
- >3 tasks in a plan
- >5 files per task
- Multiple subsystems touched
- Mixed concerns (API + UI + database in one plan)

---

## Estimating Context Per Task

| Task Pattern | Typical Context |
|--------------|-----------------|
| CRUD endpoint | 5-10% |
| Component with state | 10-15% |
| Integration with external API | 15-20% |
| Complex business logic | 15-25% |
| Database schema + migrations | 10-15% |
