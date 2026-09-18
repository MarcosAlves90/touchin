from app.authorization import get_permissions_for_role


def test_admin_has_employee_permissions():
    permissions = get_permissions_for_role("admin")
    assert "employees.read" in permissions
    assert "employees.update" in permissions
    assert "admin.cross_company" not in permissions


def test_super_admin_has_cross_company_permission():
    permissions = get_permissions_for_role("super_admin")
    assert "admin.cross_company" in permissions
    assert "companies.manage" in permissions


def test_project_permissions_by_role():
    employee_permissions = get_permissions_for_role("employee")
    assert "projects.read" in employee_permissions
    assert "projects.create" not in employee_permissions
    assert "projects.update" not in employee_permissions
    assert "projects.delete" not in employee_permissions
    assert "projects.assign" not in employee_permissions

    manager_permissions = get_permissions_for_role("manager")
    assert "projects.read" in manager_permissions
    assert "projects.create" in manager_permissions
    assert "projects.update" in manager_permissions
    assert "projects.assign" in manager_permissions
    assert "projects.delete" in manager_permissions

    admin_permissions = get_permissions_for_role("admin")
    assert "projects.read" in admin_permissions
    assert "projects.create" in admin_permissions
    assert "projects.update" in admin_permissions
    assert "projects.delete" in admin_permissions
    assert "projects.assign" in admin_permissions


def test_time_clock_management_permissions_start_at_manager():
    employee_permissions = get_permissions_for_role("employee")
    assert "time_clock.manage" not in employee_permissions

    manager_permissions = get_permissions_for_role("manager")
    assert "time_clock.manage" in manager_permissions

    admin_permissions = get_permissions_for_role("admin")
    assert "time_clock.manage" in admin_permissions

    super_admin_permissions = get_permissions_for_role("super_admin")
    assert "time_clock.manage" in super_admin_permissions


def test_task_permissions_by_role():
    employee_permissions = get_permissions_for_role("employee")
    assert "tasks.create" not in employee_permissions
    assert "tasks.update" not in employee_permissions
    assert "tasks.members.self" in employee_permissions
    assert "tasks.members.manage" not in employee_permissions

    manager_permissions = get_permissions_for_role("manager")
    assert "tasks.create" in manager_permissions
    assert "tasks.update" in manager_permissions
    assert "tasks.members.self" in manager_permissions
    assert "tasks.members.manage" in manager_permissions
