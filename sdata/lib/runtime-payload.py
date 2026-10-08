#!/usr/bin/env python3
"""Select and copy the installed shell payload using one distribution policy."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


class Payload:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.policy = json.loads((self.root / 'sdata/runtime-exclusions.json').read_text())
        self.dirs = self.read_manifest('runtime-payload-dirs.txt')
        self.files = self.read_manifest('runtime-root-files.txt')

    def read_manifest(self, name):
        entries = []
        for line in (self.root / 'sdata' / name).read_text().splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if Path(line).is_absolute() or '..' in Path(line).parts:
                raise ValueError(f'invalid runtime path: {line}')
            entries.append(line)
        return entries

    def excluded(self, relative):
        parts = Path(relative).parts
        p = self.policy
        for part in parts:
            if (part in p['excludedNames'] or
                any(part.startswith(s) for s in p['excludedNamePrefixes']) or
                any(part.endswith(s) for s in p['excludedNameSuffixes'])):
                return True
        if any(relative == s or relative.startswith(s + '/') for s in p['excludedPaths']):
            return True
        return any(str(Path(relative).parent) == d and
                   any(relative.endswith(s) for s in suffixes)
                   for d, suffixes in p['excludedDirectorySuffixes'].items())

    def check_link(self, path):
        if not path.is_symlink():
            return
        target = path.resolve()
        if Path(os.readlink(path)).is_absolute():
            raise ValueError(f'absolute runtime symlink: {path.relative_to(self.root)}')
        if not target.is_relative_to(self.root) or not target.exists():
            raise ValueError(f'escaping or dangling runtime symlink: {path.relative_to(self.root)}')
        relative = target.relative_to(self.root).as_posix()
        delivered = (relative in self.files or
                     (target.parent == self.root and target.suffix == '.qml' and target.is_file()) or
                     any(relative == d or relative.startswith(d + '/') for d in self.dirs))
        if not delivered or self.excluded(relative):
            raise ValueError(f'unsafe runtime symlink: {path.relative_to(self.root)}')

    def paths(self):
        for name in self.files:
            if self.excluded(name):
                raise ValueError(f'excluded root manifest entry: {name}')
            path = self.root / name
            if not path.is_file():
                raise ValueError(f'missing runtime file: {name}')
            self.check_link(path)
            yield name
        for path in sorted(self.root.glob('*.qml')):
            if not path.is_file() or self.excluded(path.name):
                continue
            self.check_link(path)
            yield path.name
        for name in self.dirs:
            if self.excluded(name) or not (self.root / name).is_dir():
                raise ValueError(f'invalid runtime directory: {name}')
            if (self.root / name).is_symlink():
                raise ValueError(f'runtime directory must not be a symlink: {name}')
            for base, dirs, files in os.walk(self.root / name, followlinks=False):
                for child in list(dirs):
                    path = Path(base) / child
                    rel = path.relative_to(self.root).as_posix()
                    if self.excluded(rel):
                        dirs.remove(child)
                    elif path.is_symlink():
                        self.check_link(path)
                        dirs.remove(child)
                        yield rel
                for child in sorted(files):
                    path = Path(base) / child
                    rel = path.relative_to(self.root).as_posix()
                    if not self.excluded(rel):
                        self.check_link(path)
                        yield rel

    def filters(self, subdir=''):
        p = self.policy
        rules = list(p['excludedNames'])
        rules += [s + '*' for s in p['excludedNamePrefixes']]
        rules += ['*' + s for s in p['excludedNameSuffixes']]
        for path in p['excludedPaths']:
            if not subdir:
                rules.append('/' + path)
            elif path.startswith(subdir + '/'):
                rules.append('/' + path[len(subdir) + 1:])
        for directory, suffixes in p['excludedDirectorySuffixes'].items():
            if subdir and not directory.startswith(subdir + '/'):
                continue
            relative = directory[len(subdir) + 1:] if subdir else directory
            rules += ['/' + relative + '/*' + s for s in suffixes]
        return ['--exclude=' + rule for rule in rules]

    def sync(self, target, *, subdir=None, delete=False, out_format=None):
        # Validate before writing; rsync preserves safe relative links, never dereferences them.
        list(self.paths())
        source = self.root / subdir if subdir else self.root
        target = Path(target).absolute()
        if target.is_symlink() or target.resolve() == source.resolve() or source.resolve().is_relative_to(target.resolve()) or target.resolve().is_relative_to(source.resolve()):
            raise ValueError('destination must be a separate installed directory')
        args = ['rsync', '-a', *self.filters(subdir or '')]
        if delete:
            args += ['--delete']
        if out_format:
            args += ['--out-format=' + out_format]
        if subdir is None:
            args += ['--include=/' + p.name for p in self.root.glob('*.qml') if p.is_file()]
            args += ['--include=/' + name for name in self.files]
            args += ['--include=/' + name + '/***' for name in self.dirs]
            args += ['--exclude=/*']
        target.mkdir(parents=True, exist_ok=True)
        subprocess.run([*args, str(source) + '/', str(target) + '/'], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['list', 'manifest', 'copy', 'sync-dir', 'filters', 'filter-installed'])
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--target', type=Path)
    parser.add_argument('--subdir')
    parser.add_argument('--delete', action='store_true')
    parser.add_argument('--out-format')
    args = parser.parse_args()
    payload = Payload(args.root)
    if args.command == 'filters':
        if args.subdir and ('..' in Path(args.subdir).parts or Path(args.subdir).is_absolute()):
            parser.error('invalid subdirectory')
        list(payload.paths())  # Directory installers use the same pre-copy link checks.
        print('\n'.join(payload.filters(args.subdir or '')))
        return
    if args.command == 'filter-installed':
        # Keep optional packs and private/user artifacts outside orphan cleanup. Old
        # source-only tooling remains eligible for the existing managed-file cleanup.
        payload.policy['excludedPaths'] = [p for p in payload.policy['excludedPaths']
                                           if p.startswith('assets/')]
        for line in sys.stdin:
            if not payload.excluded(line.rstrip('\n')):
                print(line.rstrip('\n'))
        return
    if args.command in ('copy', 'sync-dir'):
        if args.target is None:
            parser.error('--target is required')
        if args.command == 'sync-dir' and args.subdir not in payload.dirs:
            parser.error('--subdir must name a runtime payload directory')
        payload.sync(args.target, subdir=args.subdir if args.command == 'sync-dir' else None,
                     delete=args.delete, out_format=args.out_format)
    else:
        for name in sorted(set(payload.paths())):
            if args.command == 'list':
                print(name)
            else:
                path = payload.root / name
                checksum = (hashlib.sha256(path.read_bytes()).hexdigest()
                            if path.is_file() and path.suffix in ('.qml', '.js', '.py', '.sh', '.fish') else '')
                print(f'{name}:{checksum}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'runtime payload: {error}', file=sys.stderr)
        sys.exit(1)
