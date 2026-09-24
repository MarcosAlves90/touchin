from __future__ import annotations

from typing import Protocol

from fastapi import Depends, HTTPException, status

from app.dependencies import get_current_context

AUTH_READ_CONTEXT = "auth.read_context"
TIME_CLOCK_READ = "time_clock.read"
TIME_CLOCK_PUNCH = "time_clock.punch"
TIME_CLOCK_MANAGE = "time_clock.manage"
EMPLOYEES_READ = "employees.read"
EMPLOYEES_CREATE = "employees.create"
EMPLOYEES_UPDATE = "employees.update"
EMPLOYEES_DELETE = "employees.delete"
PROJECTS_READ = "projects.read"
PROJECTS_CREATE = "projects.create"
PROJECTS_UPDATE = "projects.update"
PROJECTS_DELETE = "projects.delete"
PROJECTS_ASSIGN = "projects.assign"
TASKS_CREATE = "tasks.create"
TASKS_UPDATE = "tasks.update"
TASKS_DELETE = "tasks.delete"
TASKS_MEMBERS_SELF = "tasks.members.self"
TASKS_MEMBERS_MANAGE = "tasks.members.manage"
KANBAN_READ = "kanban.read"
KANBAN_STRUCTURE_MANAGE = "kanban.structure.manage"
KANBAN_CARDS_MOVE = "kanban.cards.move"
KANBAN_ASSIGNEES_MANAGE = "kanban.assignees.manage"
COMPANIES_MANAGE = "companies.manage"
ADMIN_CROSS_COMPANY = "admin.cross_company"

MANAGERIAL_ROLES = frozenset({"manager", "admin", "super_admin"})

ROLE_PERMISSIONS: dict[str, set[str]] = {
    "employee": {
        AUTH_READ_CONTEXT,
        PROJECTS_READ,
        TASKS_MEMBERS_SELF,
        KANBAN_READ,
        KANBAN_CARDS_MOVE,
        KANBAN_ASSIGNEES_MANAGE,
        TIME_CLOCK_READ,
        TIME_CLOCK_PUNCH,
    },
    "manager": {
        AUTH_READ_CONTEXT,
        EMPLOYEES_READ,
        EMPLOYEES_CREATE,
        EMPLOYEES_UPDATE,
        EMPLOYEES_DELETE,
        PROJECTS_READ,
        PROJECTS_CREATE,
        PROJECTS_UPDATE,
        PROJECTS_DELETE,
        PROJECTS_ASSIGN,
        TASKS_CREATE,
        TASKS_UPDATE,
        TASKS_DELETE,
        TASKS_MEMBERS_SELF,
        KANBAN_READ,
        KANBAN_STRUCTURE_MANAGE,
        KANBAN_CARDS_MOVE,
        KANBAN_ASSIGNEES_MANAGE,
        TASKS_MEMBERS_MANAGE,
        TIME_CLOCK_READ,
        TIME_CLOCK_PUNCH,
        TIME_CLOCK_MANAGE,
    },
    "admin": {
        AUTH_READ_CONTEXT,
        COMPANIES_MANAGE,
        EMPLOYEES_READ,
        EMPLOYEES_CREATE,
        EMPLOYEES_UPDATE,
        EMPLOYEES_DELETE,
        PROJECTS_READ,
        PROJECTS_CREATE,
        PROJECTS_UPDATE,
        PROJECTS_DELETE,
        PROJECTS_ASSIGN,
        TASKS_CREATE,
        TASKS_UPDATE,
        TASKS_DELETE,
        TASKS_MEMBERS_SELF,
        KANBAN_READ,
        KANBAN_STRUCTURE_MANAGE,
        KANBAN_CARDS_MOVE,
        KANBAN_ASSIGNEES_MANAGE,
        TASKS_MEMBERS_MANAGE,
        TIME_CLOCK_READ,
        TIME_CLOCK_PUNCH,
        TIME_CLOCK_MANAGE,
    },
    "super_admin": {
        AUTH_READ_CONTEXT,
        ADMIN_CROSS_COMPANY,
        COMPANIES_MANAGE,
        EMPLOYEES_READ,
        EMPLOYEES_CREATE,
        EMPLOYEES_UPDATE,
        EMPLOYEES_DELETE,
        PROJECTS_READ,
        PROJECTS_CREATE,
        PROJECTS_UPDATE,
        PROJECTS_DELETE,
        PROJECTS_ASSIGN,
        TASKS_CREATE,
        TASKS_UPDATE,
        TASKS_DELETE,
        TASKS_MEMBERS_SELF,
        KANBAN_READ,
        KANBAN_STRUCTURE_MANAGE,
        KANBAN_CARDS_MOVE,
        KANBAN_ASSIGNEES_MANAGE,
        TASKS_MEMBERS_MANAGE,
        TIME_CLOCK_READ,
        TIME_CLOCK_PUNCH,
        TIME_CLOCK_MANAGE,
    },
}


def get_permissions_for_role(role: str) -> set[str]:
    return set(ROLE_PERMISSIONS.get(role, set()))


def is_managerial_role(role: str) -> bool:
    return role in MANAGERIAL_ROLES


class AuthorizationCompany(Protocol):
    id: str


class AuthorizationUser(Protocol):
    role: str


class AuthorizationContext(Protocol):
    company: AuthorizationCompany
    user: AuthorizationUser


def can(
    context: AuthorizationContext,
    permission: str,
    *,
    company_id: str | None = None,
    scope: str = "company",
) -> bool:
    permissions = get_permissions_for_role(context.user.role)
    if permission not in permissions:
        return False
    if scope == "global":
        return context.user.role == "super_admin"
    if company_id is not None and context.company.id != company_id:
        return False
    return True


def require_permission(permission: str, *, scope: str = "company"):
    def dependency(
        context: AuthorizationContext = Depends(get_current_context),
    ) -> AuthorizationContext:
        allowed = can(context, permission, company_id=context.company.id, scope=scope)
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Permission denied.",
            )
        return context

    return dependency
