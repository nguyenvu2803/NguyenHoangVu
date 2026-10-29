from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'dist' / 'NguyenHoangVu-source.zip'
output.parent.mkdir(exist_ok=True)
ignored = {'.git', '.venv', 'node_modules', '.dart_tool', 'build', '.gradle', '.kotlin', '.idea', '__pycache__', '.pytest_cache', '.playwright-mcp', 'dist', 'ephemeral', '.symlinks', 'Pods', 'coverage'}
excluded = {'local.properties', 'key.properties', 'production.json', '.DS_Store', '.flutter-plugins-dependencies', 'github-login.png', 'render-login.png'}
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if path.is_symlink() or not path.is_file() or set(relative.parts) & ignored or path.name in excluded:
            continue
        if path.name.startswith('.env') and path.name not in {'.env.example', '.env.production.example'}:
            continue
        if path.suffix in {'.pyc', '.db', '.keystore', '.jks', '.dump', '.pem', '.key', '.onnx'}:
            continue
        if 'service-account' in path.name or '-firebase-adminsdk-' in path.name:
            continue
        archive.write(path, Path('NguyenHoangVu') / relative)
print(output)
