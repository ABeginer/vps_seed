#!/usr/bin/env python3
"""
Supabase Tasks Synchronization Client for Hermes Agent.
Provides CLI interface for listing, updating, and inserting tasks in Supabase.
"""

import argparse
import json
import os
import sys
from typing import Any, Dict, Optional


def get_supabase_client():
    """Initialize and return the Supabase client using environment variables."""
    url = os.environ.get("SUPABASE_URL")
    # Accept SUPABASE_SECRET_KEY, with fallback to SUPABASE_SERVICE_ROLE_KEY
    key = os.environ.get("SUPABASE_SECRET_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        error_payload = {
            "error": "Missing required environment variables. Please ensure SUPABASE_URL and SUPABASE_SECRET_KEY are set.",
            "missing": [k for k, v in [("SUPABASE_URL", url), ("SUPABASE_SECRET_KEY", key)] if not v],
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)

    try:
        from supabase import create_client, Client
        client: Client = create_client(url, key)
        return client
    except ImportError:
        error_payload = {
            "error": "The 'supabase' Python package is not installed. Run 'pip install supabase' to install."
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        error_payload = {
            "error": f"Failed to initialize Supabase client: {str(e)}"
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)


def list_tasks(client, status: Optional[str] = None):
    """Query tasks from the tasks table, optionally filtering by status."""
    try:
        query = client.table("tasks").select("*")
        if status:
            query = query.eq("status", status)
        query = query.order("created_at", desc=True)
        res = query.execute()
        output = {
            "success": True,
            "count": len(res.data) if res.data else 0,
            "tasks": res.data if res.data is not None else [],
        }
        print(json.dumps(output, indent=2))
    except Exception as e:
        # Fallback if created_at ordering fails (e.g. column missing or custom schema)
        try:
            query = client.table("tasks").select("*")
            if status:
                query = query.eq("status", status)
            res = query.execute()
            output = {
                "success": True,
                "count": len(res.data) if res.data else 0,
                "tasks": res.data if res.data is not None else [],
            }
            print(json.dumps(output, indent=2))
        except Exception as inner_e:
            error_payload = {
                "error": f"Failed to list tasks from Supabase: {str(inner_e)}"
            }
            print(json.dumps(error_payload, indent=2), file=sys.stderr)
            sys.exit(1)


def update_task(client, task_id: Any, status: Optional[str] = None, output: Optional[str] = None):
    """Update task status and ai_output by ID."""
    if not task_id:
        error_payload = {"error": "--task-id is required for update action"}
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)

    update_payload: Dict[str, Any] = {}
    if status is not None:
        update_payload["status"] = status
    if output is not None:
        update_payload["ai_output"] = output

    if not update_payload:
        error_payload = {
            "error": "Nothing to update. Provide --status and/or --output."
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)

    try:
        res = client.table("tasks").update(update_payload).eq("id", task_id).execute()
        output_result = {
            "success": True,
            "task_id": task_id,
            "updated_fields": update_payload,
            "data": res.data if res.data is not None else [],
        }
        print(json.dumps(output_result, indent=2))
    except Exception as e:
        error_payload = {
            "error": f"Failed to update task {task_id}: {str(e)}"
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)


def insert_task(client, title: Optional[str], description: Optional[str], status: Optional[str] = None):
    """Insert a new task into the tasks table."""
    if not title:
        error_payload = {"error": "--title is required for insert action"}
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)

    insert_payload: Dict[str, Any] = {
        "title": title,
        "description": description or "",
        "status": status or "pending",
    }

    try:
        res = client.table("tasks").insert(insert_payload).execute()
        output_result = {
            "success": True,
            "inserted": insert_payload,
            "data": res.data if res.data is not None else [],
        }
        print(json.dumps(output_result, indent=2))
    except Exception as e:
        error_payload = {
            "error": f"Failed to insert task: {str(e)}"
        }
        print(json.dumps(error_payload, indent=2), file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Hermes Agent Supabase Tasks Synchronization Client"
    )
    parser.add_argument(
        "--action",
        choices=["list", "update", "insert"],
        required=True,
        help="Action to perform: list, update, or insert",
    )
    parser.add_argument(
        "--task-id",
        dest="task_id",
        help="Target task ID to update",
    )
    parser.add_argument(
        "--status",
        help="Task status (e.g. pending, in_progress, completed, failed)",
    )
    parser.add_argument(
        "--output",
        help="AI output or summary to store in ai_output column",
    )
    parser.add_argument(
        "--title",
        help="Task title (required for insert action)",
    )
    parser.add_argument(
        "--description",
        help="Task description or details for insert action",
    )

    args = parser.parse_args()
    client = get_supabase_client()

    if args.action == "list":
        list_tasks(client, status=args.status)
    elif args.action == "update":
        update_task(client, task_id=args.task_id, status=args.status, output=args.output)
    elif args.action == "insert":
        insert_task(client, title=args.title, description=args.description, status=args.status)


if __name__ == "__main__":
    main()
