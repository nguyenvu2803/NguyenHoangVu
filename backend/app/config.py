from functools import lru_cache
from typing import Literal
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')
    environment: Literal['development', 'production'] = 'development'
    database_url: str = 'sqlite:///./attendance.db'
    jwt_secret: str = 'development-only-change-before-production-123456789'
    public_url: str = 'http://127.0.0.1:8000'
    cors_origins: str = 'http://localhost:8080,http://127.0.0.1:8080'
    mail_provider: Literal['smtp', 'brevo'] = 'smtp'
    brevo_api_key: str = ''
    email_from: str = ''
    email_sender_name: str = 'NguyenHoangVu'
    smtp_host: str = ''
    smtp_port: int = 587
    smtp_user: str = ''
    smtp_password: str = ''
    smtp_from: str = ''
    twilio_account_sid: str = ''
    twilio_auth_token: str = ''
    twilio_from: str = ''
    google_client_id: str = ''
    google_client_secret: str = ''
    mobile_callback: str = 'nguyenhoangvu://oauth'
    seed_demo: bool = False
    demo_password: str = 'Vu@2026Demo!'
    bootstrap_admin_email: str = ''
    bootstrap_admin_password: str = ''

    def validate_production(self):
        if self.environment == 'production':
            if len(self.jwt_secret) < 40 or self.jwt_secret.lower().startswith(('development', 'replace', 'change')):
                raise RuntimeError('Production requires a unique JWT_SECRET of at least 40 characters')
            if not self.public_url.startswith('https://') or not self.database_url.startswith(('postgresql', 'postgres://')):
                raise RuntimeError('Production requires HTTPS PUBLIC_URL and PostgreSQL DATABASE_URL')
            if self.seed_demo:
                raise RuntimeError('SEED_DEMO must be false in production')
            if self.mail_provider == 'brevo':
                if not self.brevo_api_key or not self.email_from:
                    raise RuntimeError('Brevo requires BREVO_API_KEY and verified EMAIL_FROM')
            elif not all((self.smtp_host, self.smtp_user, self.smtp_password, self.smtp_from)):
                raise RuntimeError('Production SMTP requires SMTP_HOST, SMTP_USER, SMTP_PASSWORD and SMTP_FROM')
        if bool(self.bootstrap_admin_email) != bool(self.bootstrap_admin_password):
            raise RuntimeError('Set both BOOTSTRAP_ADMIN_EMAIL and BOOTSTRAP_ADMIN_PASSWORD or neither')


@lru_cache
def settings():
    result = Settings()
    result.validate_production()
    return result
