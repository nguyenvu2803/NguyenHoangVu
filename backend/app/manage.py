import argparse
import getpass
from .database import Base, engine, Session
from .bootstrap import provision_admin


def main():
    parser = argparse.ArgumentParser(description='NguyenHoangVu administrative tools')
    parser.add_argument('command', choices=['create-admin'])
    parser.add_argument('--email', required=True)
    parser.add_argument('--name', default='Quản trị viên')
    args = parser.parse_args()
    password = getpass.getpass('Admin password (at least 14 characters): ')
    if password != getpass.getpass('Repeat password: '):
        raise SystemExit('Passwords do not match')
    Base.metadata.create_all(engine)
    with Session() as db:
        created = provision_admin(db, args.email, password, args.name)
    print('Admin created; verify email OTP on first login.' if created else 'Admin already exists; no changes made.')


if __name__ == '__main__':
    main()
