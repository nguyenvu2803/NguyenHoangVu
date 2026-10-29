"""Read-only HTTPS smoke check using Python standard library."""
import argparse
import ipaddress
import json
import urllib.error
import urllib.request
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('url', help='Actual deployed HTTPS API origin')
args = parser.parse_args()
base = args.url.rstrip('/')
parsed = urlparse(base)
if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password
        or parsed.query or parsed.fragment or parsed.path not in ('', '/')
        or parsed.hostname.lower() == 'localhost'
        or parsed.hostname.lower().endswith(('.localhost', '.local'))):
    raise SystemExit('Expected a public HTTPS API URL')
try:
    address = ipaddress.ip_address(parsed.hostname)
except ValueError:
    address = None
if address is not None and not address.is_global:
    raise SystemExit('Expected a public HTTPS API URL')
for path, expected in [('/health', 200), ('/employees', 401), ('/attendance', 401)]:
    try:
        with urllib.request.urlopen(base + path, timeout=90) as response:
            status = response.status
            body = response.read()
    except urllib.error.HTTPError as error:
        status = error.code
        body = error.read()
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit(f'FAIL {path}: deployed API unreachable; check service status and retry')
    if status != expected:
        raise SystemExit(f'FAIL {path}: expected {expected}, got {status}')
    if path == '/health':
        data = json.loads(body)
        if data.get('environment') != 'production':
            raise SystemExit('Health endpoint does not report production mode')
    print(f'PASS {path}: {status}')
print('Public HTTPS deployment passed smoke checks. Test OTP/OAuth and device features separately.')
