---
name: supabase_tasks
description: "Synchronize and update sales tasks directly in Supabase"
tools:
  - run_command
allowed_tools:
  - run_command
---

# Supabase Tasks Synchronization Skill

This skill enables the Hermes Agent to query, claim, execute, and record results on tasks stored in the Supabase `tasks` table.

## Prerequisites
- Python 3 with the `supabase` SDK installed (`pip install supabase`).
- Persistent environment variables:
  - `SUPABASE_URL`: The Supabase project endpoint (e.g., `https://wlzhcjogingzpvudlaze.supabase.co`).
  - `SUPABASE_SECRET_KEY`: Supabase service role / secret key (`sb_secret_...`).

## CLI Client Script Location
The client automation script is installed at:
`%USERPROFILE%\.hermes\skills\supabase_tasks\tasks_client.py`

---

## Command Syntax & Operations

### 1. Listing Tasks
Fetch pending tasks waiting for processing:
```bash
python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action list --status pending
```

Fetch all tasks across all statuses:
```bash
python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action list
```

### 2. Updating Task Status & AI Output
When claiming and beginning work on a task, transition status to `in_progress`:
```bash
python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action update --task-id <TASK_ID> --status in_progress
```

When work is completed, mark status as `completed` and supply the output summary in `--output`:
```bash
python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action update --task-id <TASK_ID> --status completed --output "Completed task execution and verified database synchronization."
```

If an error or unrecoverable issue occurs during execution, mark as `failed`:
```bash
python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action update --task-id <TASK_ID> --status failed --output "Task failed: <Error description>"
```

### 3. Inserting New Tasks
Create and record a new task into the Supabase pipeline:
```bash
python "$HOME\.hermes\skills\supabase_tasks\tasks_client.py" --action insert --title "<Task Title>" --description "<Task Description>" --status pending
```

---

## Lifecycle Protocol for Hermes Agent
1. **Poll / Query**: When requested to check tasks, run `--action list --status pending`.
2. **Lock / Claim**: Mark the chosen task `--status in_progress` to avoid duplicate processing.
3. **Execute**: Perform the requested workflow using available tools (local file access, web search, code generation).
4. **Report**: Finalize the task with `--action update --task-id <ID> --status completed --output "<Detailed AI Output>"`.
