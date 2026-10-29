from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
output = root / 'dist' / 'NguyenHoangVu-source.zip'
output.parent.mkdir(exist_ok=True)
ignored = {'.git', '.venv', '.dart_tool', 'build', '.gradle', '.idea', '__pycache__', '.pytest_cache', '.playwright-mcp', 'dist', 'ephemeral', '.symlinks', 'Pods'}
excluded = {'local.properties', 'key.properties', 'production.json', '.env', '.env.production', '.DS_Store', '.flutter-plugins-dependencies'}
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if not path.is_file() or set(relative.parts) & ignored or path.name in excluded:
            continue
        if path.suffix in {'.pyc', '.db', '.keystore', '.jks', '.dump'}:
            continue
        archive.write(path, Path('NguyenHoangVu') / relative)
print(output)
