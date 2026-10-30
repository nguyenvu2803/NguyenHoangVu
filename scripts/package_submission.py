"""Assemble only explicit public deliverables; never include private dist files."""
from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
dist = root / 'dist'
name = 'NguyenHoangVu_2380602586_NopBai'
folder = dist / name
if subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip():
    raise SystemExit('Commit reviewed source changes before packaging so SOURCE_COMMIT is accurate.')
subprocess.run(['python3', 'scripts/package_source.py'], cwd=root, check=True)
folder.mkdir(exist_ok=True)
files = {
    'NguyenHoangVu.apk': dist / 'NguyenHoangVu.apk',
    'NguyenHoangVu-source.zip': dist / 'NguyenHoangVu-source.zip',
    'NguyenHoangVu-chat-backend.patch': dist / 'NguyenHoangVu-chat-backend.patch',
    'NguyenHoangVu-face-settings-backend.patch': dist / 'NguyenHoangVu-face-settings-backend.patch',
    'hovaten.txt': root / 'hovaten.txt',
    **{file: root / 'docs' / file for file in ['KICH_BAN_VIDEO.md', 'NOP_BAI.md',
       'VERIFICATION.md', 'DEPLOY_CHAT.md', 'SETTINGS_FACE_LOGIN.md', 'ui-fixture-chat-mobile.png',
       'ui-fixture-settings-mobile.png']},
}
for filename, source in files.items():
    if not source.is_file():
        raise SystemExit(f'Missing deliverable: {filename}')
    shutil.copy2(source, folder / filename)
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
(folder / 'SOURCE_COMMIT.txt').write_text(commit + '\n')
(folder / 'DOC_TRUOC_KHI_NOP.txt').write_text(
    'Nguyễn Hoàng Vũ - 2380602586\n'
    'Một APK Flutter, ba giao diện theo quyền.\n'
    'Ba chức năng chọn: khuôn mặt, định vị, dịch tin nhắn realtime.\n'
    'Đọc VERIFICATION.md: test tách biệt không thay nghiệm thu production.\n'
    'Chủ API cần deploy chat/Cài đặt và migration 005–006, cấp tài khoản active/quyền test.\n'
    'Điền link YouTube thật vào hovaten.txt và NOP_BAI.md sau khi quay.\n'
    'Ảnh ui-fixture-chat-mobile.png là dữ liệu mẫu, không phải chat production.\n'
    'Không nộp file mật khẩu/token/OTP hoặc nội dung dist khác ngoài gói này.\n'
)
names = sorted([*files, 'SOURCE_COMMIT.txt', 'DOC_TRUOC_KHI_NOP.txt'])
(folder / 'SHA256SUMS.txt').write_text(''.join(
    f'{sha256((folder / filename).read_bytes()).hexdigest()}  {filename}\n' for filename in names
))
with zipfile.ZipFile(dist / f'{name}.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for filename in [*names, 'SHA256SUMS.txt']:
        archive.write(folder / filename, f'{name}/{filename}')
print(dist / f'{name}.zip')
