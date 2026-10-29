import logging
import smtplib
from email.message import EmailMessage
import httpx
from fastapi import HTTPException
from .config import settings

logger = logging.getLogger('uvicorn.error')


def deliver_otp(user, channel, code):
    cfg = settings()
    if cfg.environment != 'production' and cfg.mail_provider == 'smtp' and not cfg.smtp_host and channel == 'email':
        logger.warning('DEVELOPMENT OTP for %s: %s', user.email, code)
        return
    try:
        if channel == 'email' and cfg.mail_provider == 'brevo':
            if not cfg.brevo_api_key or not cfg.email_from:
                raise HTTPException(503, 'Email OTP chưa được cấu hình')
            response = httpx.post(
                'https://api.brevo.com/v3/smtp/email',
                headers={'api-key': cfg.brevo_api_key, 'accept': 'application/json'},
                json={
                    'sender': {'name': cfg.email_sender_name, 'email': cfg.email_from},
                    'to': [{'email': user.email}],
                    'subject': 'NguyenHoangVu - Mã xác thực',
                    'textContent': f'Mã xác thực: {code}\nHiệu lực 5 phút. Không chia sẻ mã này.',
                },
                timeout=12,
            )
            response.raise_for_status()
        elif channel == 'email':
            message = EmailMessage()
            message['From'] = cfg.smtp_from or cfg.smtp_user
            message['To'] = user.email
            message['Subject'] = 'NguyenHoangVu - Mã xác thực'
            message.set_content(f'Mã xác thực: {code}\nHiệu lực 5 phút. Không chia sẻ mã này.')
            with smtplib.SMTP(cfg.smtp_host, cfg.smtp_port, timeout=12) as smtp:
                smtp.starttls()
                smtp.login(cfg.smtp_user, cfg.smtp_password)
                smtp.send_message(message)
        else:
            if not cfg.twilio_account_sid or not user.phone:
                raise HTTPException(503, 'SMS chưa được cấu hình hoặc tài khoản chưa có số điện thoại')
            response = httpx.post(f'https://api.twilio.com/2010-04-01/Accounts/{cfg.twilio_account_sid}/Messages.json', auth=(cfg.twilio_account_sid, cfg.twilio_auth_token), data={'To': user.phone, 'From': cfg.twilio_from, 'Body': f'NguyenHoangVu OTP: {code}. Expires in 5 minutes.'}, timeout=12)
            response.raise_for_status()
    except HTTPException:
        raise
    except Exception as exc:
        status = getattr(getattr(exc, 'response', None), 'status_code', None)
        logger.error('OTP provider failed (%s, HTTP status=%s)', type(exc).__name__, status)
        raise HTTPException(503, 'Dịch vụ OTP tạm thời không khả dụng, vui lòng thử lại')
