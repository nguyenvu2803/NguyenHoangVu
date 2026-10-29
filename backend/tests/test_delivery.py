from types import SimpleNamespace
import httpx
import pytest
from fastapi import HTTPException
from app.config import Settings
from app import delivery


def brevo_settings(**changes):
    return Settings(
        environment='production', database_url='postgresql://user:pass@db/attendance',
        public_url='https://app.onrender.com', jwt_secret='test-only-unique-secret-' + 'x' * 48,
        seed_demo=False, mail_provider='brevo',
        brevo_api_key=changes.pop('brevo_api_key', 'test-only-brevo-key'),
        email_from=changes.pop('email_from', 'sender@example.com'), **changes,
    )


def test_brevo_production_works_without_smtp():
    brevo_settings(smtp_host='', smtp_user='', smtp_password='', smtp_from='').validate_production()
    for changes in ({'brevo_api_key': ''}, {'email_from': ''}):
        with pytest.raises(RuntimeError):
            brevo_settings(**changes).validate_production()


def test_brevo_sends_otp_over_https_without_smtp(monkeypatch, caplog):
    cfg = brevo_settings()
    monkeypatch.setattr(delivery, 'settings', lambda: cfg)
    monkeypatch.setattr(delivery.smtplib, 'SMTP', lambda *args, **kwargs: pytest.fail('SMTP must not be used'))
    sent = []

    def post(url, **kwargs):
        sent.append((url, kwargs))
        return httpx.Response(201, json={'messageId': 'test-id'}, request=httpx.Request('POST', url))

    monkeypatch.setattr(delivery.httpx, 'post', post)
    delivery.deliver_otp(SimpleNamespace(email='recipient@example.com'), 'email', '123456')
    url, kwargs = sent[0]
    assert url == 'https://api.brevo.com/v3/smtp/email'
    assert kwargs['headers']['api-key'] == cfg.brevo_api_key
    assert kwargs['json']['sender']['email'] == cfg.email_from
    assert kwargs['json']['to'] == [{'email': 'recipient@example.com'}]
    assert '123456' in kwargs['json']['textContent']
    assert '123456' not in caplog.text and cfg.brevo_api_key not in caplog.text


@pytest.mark.parametrize('status', [401, 429, 500])
def test_brevo_rejection_does_not_fall_back_or_expose_secrets(monkeypatch, caplog, status):
    cfg = brevo_settings()
    monkeypatch.setattr(delivery, 'settings', lambda: cfg)
    monkeypatch.setattr(delivery.smtplib, 'SMTP', lambda *args, **kwargs: pytest.fail('No SMTP fallback'))
    monkeypatch.setattr(delivery.httpx, 'post', lambda url, **kwargs: httpx.Response(status, json={'message': 'provider failure'}, request=httpx.Request('POST', url)))
    with pytest.raises(HTTPException) as error:
        delivery.deliver_otp(SimpleNamespace(email='recipient@example.com'), 'email', '123456')
    assert error.value.status_code == 503
    assert '123456' not in caplog.text and cfg.brevo_api_key not in caplog.text


def test_brevo_missing_credentials_never_logs_development_otp(monkeypatch, caplog):
    cfg = Settings(environment='development', mail_provider='brevo', brevo_api_key='', email_from='')
    monkeypatch.setattr(delivery, 'settings', lambda: cfg)
    with pytest.raises(HTTPException) as error:
        delivery.deliver_otp(SimpleNamespace(email='recipient@example.com'), 'email', '123456')
    assert error.value.status_code == 503
    assert '123456' not in caplog.text


def test_brevo_provider_failure_cannot_issue_login_session(ctx, monkeypatch):
    from app.models import Challenge, RefreshToken
    from app.database import Session
    from app import main
    from sqlalchemy import select
    client, _, _ = ctx
    cfg = brevo_settings()
    monkeypatch.setattr(delivery, 'settings', lambda: cfg)
    monkeypatch.setattr(main, 'deliver_otp', delivery.deliver_otp)
    monkeypatch.setattr(delivery.httpx, 'post', lambda url, **kwargs: httpx.Response(429, request=httpx.Request('POST', url)))
    response = client.post('/auth/login', json={'email': 'employee@example.com', 'password': 'Password123!', 'channel': 'email'})
    assert response.status_code == 503
    assert 'access_token' not in response.json()
    with Session() as db:
        assert db.scalar(select(Challenge.id)) is None
        assert db.scalar(select(RefreshToken.digest)) is None
