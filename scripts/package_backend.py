"""Package the active Node backend without credentials, dependencies or models."""
from hashlib import sha256
from pathlib import Path
import json
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
backend = root / 'backend_shared'
dist = root / 'dist'
dist.mkdir(exist_ok=True)
output = dist / 'NguyenHoangVu_Backend_2380602586.zip'
files = []
for name in ['src', 'migrations', 'test', 'test-support', 'tool', 'docs']:
    for path in (backend / name).rglob('*'):
        relative = path.relative_to(backend)
        if path.is_symlink() or not path.is_file():
            continue
        if {'node_modules', 'models', '__pycache__', 'dist', 'coverage'} & set(relative.parts):
            continue
        if path.name.startswith('.env') or path.suffix in {'.log', '.pem', '.key', '.onnx', '.pyc'}:
            continue
        files.append(path)
for name in ['package.json', 'package-lock.json', '.env.example', '.dockerignore',
             'Dockerfile', 'render.yaml', 'README.md', 'INTEGRATION_NGUYENHOANGVU.md']:
    files.append(backend / name)
for path in files:
    if not path.is_file():
        raise SystemExit(f'Missing backend source: {path.name}')
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip())
manifest = {'project': 'NguyenHoangVu', 'studentId': '2380602586', 'sourceCommit': commit,
            'includesUncommittedChanges': dirty,
            'files': {str(p.relative_to(backend)): sha256(p.read_bytes()).hexdigest() for p in sorted(files)}}
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, Path('NguyenHoangVu_Backend') / path.relative_to(backend))
    archive.writestr('NguyenHoangVu_Backend/SOURCE_MANIFEST.json', json.dumps(manifest, indent=2) + '\n')
print(output)
