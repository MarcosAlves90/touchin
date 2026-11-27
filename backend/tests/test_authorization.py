from dataclasses import dataclass

from app.authorization import can


@dataclass
class _Company:
    id: str


@dataclass
class _User:
    role: str
    must_change_password: bool = False


@dataclass
class _Context:
    company: _Company
    user: _User


def test_admin_can_access_company_scoped_employee_update():
    context = _Context(company=_Company(id="cmp-01"), user=_User(role="admin"))
    assert can(context, "employees.update", company_id="cmp-01") is True


def test_admin_cannot_access_global_admin_route():
    context = _Context(company=_Company(id="cmp-01"), user=_User(role="admin"))
    assert can(context, "admin.cross_company", scope="global") is False


def test_super_admin_can_access_global_admin_route():
    context = _Context(company=_Company(id="cmp-01"), user=_User(role="super_admin"))
    assert can(context, "admin.cross_company", scope="global") is True
