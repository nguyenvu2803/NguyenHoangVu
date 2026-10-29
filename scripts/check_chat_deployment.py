"""Check public chat capability without credentials or production writes."""
import json
import sys
from urllib.parse import urlparse
from urllib.request import urlopen

endpoint = (sys.argv[1] if len(sys.argv) > 1 else
            'https://nguyen-hoai-nam-2380601398-api.onrender.com/v1').rstrip('/')
parsed = urlparse(endpoint)
if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
    raise SystemExit('Expected public HTTPS API URL without credentials.')
try:
    with urlopen(endpoint + '/health', timeout=90) as response:
        data = json.load(response).get('data', {})
except Exception:
    raise SystemExit('Could not read public API health. Check network or cold start.')
if data.get('features', {}).get('realtimeChat') is not True:
    raise SystemExit('Chat NOT deployed: ask API owner to deploy migration 005 and chat routes. See docs/DEPLOY_CHAT.md.')
print('Public API advertises realtimeChat=true. Still verify two authorized Android clients before acceptance.')
