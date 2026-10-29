"""Read-only checks for shared public attendance API; never sends credentials."""
import argparse
import ipaddress
import json
import urllib.error
import urllib.request
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('url', nargs='?', default='https://nguyen-hoai-nam-2380601398-api.onrender.com/v1')
args = parser.parse_args()
base = args.url.rstrip('/')
parsed = urlparse(base)
if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password
        or parsed.query or parsed.fragment or parsed.path != '/v1'
        or parsed.hostname.lower() == 'localhost'
        or parsed.hostname.lower().endswith(('.localhost', '.local'))):
    raise SystemExit('Expected public HTTPS API base ending in /v1')
try:
    address = ipaddress.ip_address(parsed.hostname)
except ValueError:
    address = None
if address is not None and not address.is_global:
    raise SystemExit('Expected public HTTPS API URL')
for path, expected in [('/health', 200), ('/me', 401), ('/employees', 401), ('/attendance', 401)]:
    try:
        with urllib.request.urlopen(base + path, timeout=90) as response:
            status, body = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, body = error.code, error.read()
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit(f'FAIL {path}: API unreachable; check service status and retry')
    if status != expected:
        raise SystemExit(f'FAIL {path}: expected {expected}, got {status}')
    data = json.loads(body)
    if path == '/health' and data.get('data', {}).get('status') != 'ok':
        raise SystemExit('FAIL health: unexpected response')
    if expected == 401 and data.get('error', {}).get('code') != 'AUTH_REQUIRED':
        raise SystemExit(f'FAIL {path}: unexpected authentication envelope')
    print(f'PASS {path}: HTTP {status}')
print('Public HTTPS checks passed. OTP, authorized CRUD, GPS, face and QR still require active account/device testing.')
