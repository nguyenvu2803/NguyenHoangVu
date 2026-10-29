"""Run the real Dart API client against isolated Express/pg-mem, not production."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
node = shutil.which('node')
flutter = shutil.which('flutter')
if not node or not flutter:
    raise SystemExit('Put Node.js >=22 and Flutter on PATH first.')
version = subprocess.check_output([node, '--version'], text=True).strip()
if int(version.removeprefix('v').split('.')[0]) < 22:
    raise SystemExit('Node.js >=22 is required; change PATH before running.')
with tempfile.TemporaryDirectory(prefix='nguyenhoangvu-contract-') as directory:
    server = subprocess.Popen(
        [node, 'tool/flutter-contract-server.js'], cwd=root / 'backend_shared',
        env={**os.environ, 'NODE_ENV': 'test', 'NHV_TEST_DIRECTORY': directory},
        stdout=subprocess.PIPE, text=True,
    )
    try:
        config = json.loads(server.stdout.readline())
        print('Testing Dart client against isolated Express/pg-mem; email uses a private test mailbox.', flush=True)
        result = subprocess.run([
            flutter, 'test', '--no-pub', 'tool/backend_integration_test.dart',
            '--dart-define=ALLOW_INSECURE_DEV=true',
            '--dart-define=NHV_TEST_API_URL=' + config['endpoint'],
            '--dart-define=NHV_TEST_MAILBOX_FILE=' + config['mailboxFile'],
            '--dart-define=NHV_TEST_FACE_FILE=' + config['faceFile'],
        ], cwd=root / 'mobile')
        if result.returncode:
            raise SystemExit(result.returncode)
    finally:
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
