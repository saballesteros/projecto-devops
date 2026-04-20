"""
Pruebas unitarias - una por cada endpoint de la API del microservicio Blacklist.

Stack: pytest + unittest.mock (biblioteca estandar de Python).
No requieren motor de BD real: las operaciones de SQLAlchemy se mockean.
"""
from unittest.mock import patch, MagicMock


def test_health_endpoint_returns_ok(client):
    """GET /health -> 200 con payload de estado."""
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy", "version": "1.0.4"}


@patch("app.resources.blacklist.db.session")
def test_post_blacklist_creates_entry(mock_session, client, auth_headers):
    """POST /blacklists -> 201 e invoca db.session.add y db.session.commit una vez."""
    payload = {
        "email": "user@test.com",
        "app_uuid": "11111111-1111-1111-1111-111111111111",
        "blocked_reason": "spam",
    }

    response = client.post("/blacklists", headers=auth_headers, json=payload)

    assert response.status_code == 201
    assert response.get_json() == {
        "message": "Email agregado a la lista negra exitosamente"
    }
    mock_session.add.assert_called_once()
    mock_session.commit.assert_called_once()


def test_post_blacklist_requires_token(client):
    """POST /blacklists -> 401 cuando no se envia token."""
    response = client.post("/blacklists", json={"email": "user@test.com"})

    assert response.status_code == 401
    assert response.get_json() == {"message": "Token de autorizacion requerido"}


def test_post_blacklist_rejects_invalid_token(client):
    """POST /blacklists -> 401 cuando el token no coincide."""
    headers = {"Authorization": "Bearer bad-token", "Content-Type": "application/json"}

    response = client.post("/blacklists", headers=headers, json={"email": "user@test.com"})

    assert response.status_code == 401
    assert response.get_json() == {"message": "Token invalido o expirado"}


def test_post_blacklist_requires_json(client, auth_headers):
    """POST /blacklists -> 400 cuando el cuerpo no es JSON."""
    response = client.post("/blacklists", headers=auth_headers, data="no-json")

    assert response.status_code == 400
    assert response.get_json() == {"message": "El cuerpo de la solicitud debe ser JSON"}


def test_post_blacklist_validates_required_fields(client, auth_headers):
    """POST /blacklists -> 400 cuando faltan campos requeridos."""
    response = client.post("/blacklists", headers=auth_headers, json={"email": "user@test.com"})

    assert response.status_code == 400
    assert response.get_json()["message"] == "Datos invalidos"
    assert "app_uuid" in response.get_json()["errors"]


@patch("app.resources.blacklist.BlacklistEntry")
def test_get_blacklist_returns_status(mock_entry, client, auth_headers):
    """GET /blacklists/<email> -> 200 con is_blacklisted=True cuando el registro existe."""
    fake_entry = MagicMock(blocked_reason="spam")
    mock_entry.query.filter_by.return_value.first.return_value = fake_entry

    response = client.get("/blacklists/user@test.com", headers=auth_headers)

    assert response.status_code == 200
    assert response.get_json() == {
        "is_blacklisted": True,
        "blocked_reason": "spam",
    }
    mock_entry.query.filter_by.assert_called_once_with(email="user@test.com")


@patch("app.resources.blacklist.BlacklistEntry")
def test_get_blacklist_returns_false_when_email_not_found(mock_entry, client, auth_headers):
    """GET /blacklists/<email> -> 200 con is_blacklisted=False cuando no existe."""
    mock_entry.query.filter_by.return_value.first.return_value = None

    response = client.get("/blacklists/user@test.com", headers=auth_headers)

    assert response.status_code == 200
    assert response.get_json() == {
        "is_blacklisted": False,
        "blocked_reason": "",
    }
    mock_entry.query.filter_by.assert_called_once_with(email="user@test.com")
