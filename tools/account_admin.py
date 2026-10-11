#!/usr/bin/env python3
"""Local-only administration; passwords use getpass, never command arguments."""
import argparse
import getpass
import sys
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parents[1]))
from accounts.service import Store
from common import ROOT, load_env


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['bootstrap', 'sync-founder', 'register', 'reset', 'delete', 'grant', 'list'])
    parser.add_argument('--nick')
    parser.add_argument('--flags', default='')
    args = parser.parse_args()
    store = Store(ROOT / 'data/accounts.sqlite3')
    if args.operation in ('bootstrap', 'sync-founder'):
        env = load_env()
        changed = store.bootstrap(env['FOUNDER_NICK'], env['FOUNDER_PASSWORD'], sync=args.operation == 'sync-founder')
        print('Kurucu olusturuldu/guncellendi.' if changed else 'Mevcut kurucu korundu.')
    elif args.operation == 'list':
        with store.db() as db:
            for nick, flags, founder in db.execute('SELECT nick,flags,founder FROM accounts ORDER BY nick_key'):
                print(nick, ''.join(chr(97 + i) for i in range(21) if flags & (1 << i)), 'kurucu' if founder else '')
    else:
        if not args.nick:
            parser.error('--nick gerekli')
        if any(c not in 'abcdefghijklmnopqrstu' for c in args.flags):
            parser.error('--flags yalnizca a..u harfleri icerebilir')
        password = getpass.getpass('Yeni sifre: ') if args.operation in ('register', 'reset') else ''
        store.change(args.operation.upper(), args.nick, password, sum(1 << (ord(c) - 97) for c in set(args.flags)))
        print('Islem tamamlandi. Aktif oyuncular en gec 5 saniyede tekrar dogrulanir.')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
