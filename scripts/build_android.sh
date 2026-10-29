#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../mobile"
if [[ ! -f config/production.json ]]; then
  echo 'Copy config/production.example.json to config/production.json and set deployed HTTPS API URL.'
  exit 1
fi
python3 - <<'PY'
import json
import subprocess
import sys
from urllib.parse import urlparse
config = json.load(open('config/production.json'))
url = urlparse(config.get('API_BASE_URL', ''))
if url.scheme != 'https' or not url.hostname or 'your-' in url.hostname.lower() or url.hostname in ('localhost','127.0.0.1'):
    raise SystemExit('API_BASE_URL must be a real deployed HTTPS URL')
if str(config.get('DEMO_MODE', '')).lower() != 'false':
    raise SystemExit('DEMO_MODE must be false for the submitted application')
if str(config.get('SHOW_DEMO', '')).lower() != 'false':
    raise SystemExit('SHOW_DEMO must be false for the submitted application')
if str(config.get('ALLOW_INSECURE_DEV', '')).lower() != 'false':
    raise SystemExit('ALLOW_INSECURE_DEV must be false for the submitted application')
subprocess.run([sys.executable, '../scripts/check_deployment.py', config['API_BASE_URL']], check=True)
PY
flutter pub get
flutter build apk --release --dart-define-from-file=config/production.json
mkdir -p ../dist
cp build/app/outputs/flutter-apk/app-release.apk ../dist/NguyenHoangVu.apk
