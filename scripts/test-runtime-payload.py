#!/usr/bin/env python3
"""Exercise distribution boundaries in temporary trees; never touch the live shell."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'sdata/lib/runtime-payload.py'
spec = importlib.util.spec_from_file_location('runtime_payload', TOOL)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='inir payload ')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / 'source'
        self.source.mkdir()
        self.target = self.base / 'installed'
        for name in ['sdata/runtime-root-files.txt', 'sdata/runtime-payload-dirs.txt',
                     'sdata/runtime-exclusions.json', 'sdata/lib/runtime-payload.py',
                     'sdata/lib/functions.sh', 'sdata/lib/robust-update.sh']:
            self.put(name, (ROOT / name).read_text())
        self.payload = module.Payload(self.source)
        for name in self.payload.dirs:
            (self.source / name).mkdir(exist_ok=True)
        for name in self.payload.files:
            self.put(name, 'fixture\n')
        self.put('VERSION', '2.30.0\n')
        # Public runtime consumers and same-name nested product directories survive.
        self.required = ['shell.qml', 'scripts/inir', 'scripts/ai/discover-provider-models.py',
                         'scripts/setup/spotify.sh', 'scripts/setup/_scan.sh',
                         'scripts/lib/ipc-registry.sh', 'scripts/colors/opencode/theme_generator.py',
                         'modules/panel/tools/control.qml', 'modules/Live.qml',
                         'assets/images/mascot/manifest.json', 'translations/en_US.json']
        for name in self.required:
            self.put(name, 'runtime fixture\n')
        self.forbidden = ['modules/AGENTS.md', 'scripts/GEMINI.md.local', 'services/.crush/session.json',
                          'scripts/.agents/skills/example/SKILL.md', 'modules/.env.local',
                          'scripts/node_modules/example.js', 'scripts/release.sh',
                          'sdata/dist-arch/inir-deps/pkg/staged-helper',
                          'scripts/orbit-visual-audit.sh', 'scripts/lib/generate-ipc-registry.py',
                          'scripts/quickshell-webengine/PKGBUILD', 'translations/tools/tool.py',
                          'translations/l10n/README.md', 'assets/images/mascot/inir-mascot-local.png',
                          'assets/images/mascot/frames/frame.png', 'assets/images/mascot/PROMPTS.md']
        for name in self.forbidden:
            self.put(name, 'EXCLUDED_SENTINEL\n')
        self.put('assets/icons/real.svg', '<svg/>')
        (self.source / 'assets/icons/link.svg').symlink_to('real.svg')

    def put(self, name, text):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_command(self, args, **kwargs):
        result = subprocess.run(args, cwd=self.source, text=True, capture_output=True, **kwargs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def assert_payload(self, target):
        for name in self.required:
            self.assertTrue((target / name).is_file(), name)
        for name in self.forbidden:
            self.assertFalse((target / name).exists(), name)
        self.assertTrue((target / 'assets/icons/link.svg').is_symlink())
        for file in target.rglob('*'):
            if file.is_file():
                self.assertNotIn(b'EXCLUDED_SENTINEL', file.read_bytes(), str(file))

    def test_copy_manifest_and_safe_symlinks(self):
        self.payload.sync(self.target)
        self.assert_payload(self.target)
        expected = set(self.payload.paths())
        actual = {p.relative_to(self.target).as_posix() for p in self.target.rglob('*') if p.is_file()}
        self.assertEqual(expected, actual)
        output = self.run_command(['python3', str(TOOL), 'manifest', '--root', str(self.source)])
        self.assertEqual(expected, {line.split(':', 1)[0] for line in output.splitlines()})

    def test_update_deletes_obsolete_runtime_but_preserves_optional_pack(self):
        self.payload.sync(self.target)
        (self.target / 'scripts/obsolete.sh').write_text('obsolete')
        (self.target / 'scripts/release.sh').write_text('old source-only tooling')
        (self.target / 'assets/images/mascot/inir-mascot-installed.png').write_text('optional pack')
        (self.target / 'modules/AGENTS.md').write_text('user-owned local file')
        self.put('modules/Live.qml', 'updated')
        self.payload.sync(self.target, delete=True)
        self.assertFalse((self.target / 'scripts/obsolete.sh').exists())
        # Excluded source-only tooling is preserved by rsync itself so updates do not
        # use --delete-excluded, then removed by the managed orphan-cleanup contract.
        self.assertTrue((self.target / 'scripts/release.sh').exists())
        self.assertEqual((self.target / 'modules/Live.qml').read_text(), 'updated')
        self.assertEqual((self.target / 'assets/images/mascot/inir-mascot-installed.png').read_text(), 'optional pack')
        self.assertEqual((self.target / 'modules/AGENTS.md').read_text(), 'user-owned local file')
        self.run_command(['bash', '-c', '''
set -euo pipefail
export REPO_ROOT="$1" XDG_CONFIG_HOME="$2/config" XDG_STATE_HOME="$2/state"
source "$1/sdata/lib/robust-update.sh"
log_info() { :; }
generate_manifest "$1" "$2/installed/.inir-manifest"
get_orphan_files "$2/installed" "$2/installed/.inir-manifest" > "$2/orphans"
cleanup_orphans "$2/installed" "$2/installed/.inir-manifest"
''', 'fixture', str(self.source), str(self.base)])
        self.assertEqual((self.base / 'orphans').read_text(), 'scripts/release.sh\n')
        self.assertFalse((self.target / 'scripts/release.sh').exists())
        self.assertEqual((self.target / 'assets/images/mascot/inir-mascot-installed.png').read_text(), 'optional pack')
        self.assertEqual((self.target / 'modules/AGENTS.md').read_text(), 'user-owned local file')

    def test_update_retires_stale_checkout(self):
        # A clone that once ran in place keeps its old HEAD; synced over, it blocks every later pull.
        (self.target / '.git').mkdir(parents=True)
        (self.target / '.git/HEAD').write_text('ref: refs/heads/main\n')
        state = self.base / 'state'
        with mock.patch.dict(os.environ, {'XDG_STATE_HOME': str(state)}):
            self.payload.sync(self.target, delete=True)
        self.assertFalse((self.target / '.git').exists())
        retired = list((state / 'quickshell/backups').glob('runtime-git-*'))
        self.assertEqual(len(retired), 1)
        self.assertEqual((retired[0] / 'HEAD').read_text(), 'ref: refs/heads/main\n')
        self.assert_payload(self.target)

    def test_install_retires_only_a_separate_checkout(self):
        env = {**os.environ, 'XDG_STATE_HOME': str(self.base / 'state')}
        command = ['python3', str(TOOL), 'retire-checkout', '--root', str(self.source), '--target', str(self.target)]
        (self.source / '.git').mkdir()
        self.target.symlink_to(self.source, target_is_directory=True)
        self.run_command(command, env=env)
        self.assertTrue((self.source / '.git').is_dir())
        self.target.unlink()
        (self.target / '.git').mkdir(parents=True)
        self.run_command(command, env=env)
        self.assertFalse((self.target / '.git').exists())
        self.assertEqual(len(list((self.base / 'state/quickshell/backups').glob('runtime-git-*'))), 1)

    def test_actual_directory_sync_functions(self):
        self.run_command(['bash', '-c', '''
set -euo pipefail
source "$1/sdata/lib/functions.sh"
x() { "$@"; }
INSTALLED_LISTFILE="$2/installed-files"
for dir in modules services scripts assets translations defaults dots sdata; do
  rsync_dir__sync "$1/$dir" "$2/installed/$dir"
done
''', 'fixture', str(self.source), str(self.base)])
        # Directory sync intentionally does not copy root entrypoints.
        self.required.remove('shell.qml')
        self.assert_payload(self.target)
        # Generic config subdirectories keep unrelated tools/ names.
        self.put('dots/.config/example/tools/tool.txt', 'user config')
        self.run_command(['bash', '-c', '''
set -euo pipefail
source "$1/sdata/lib/functions.sh"
x() { "$@"; }
INSTALLED_LISTFILE="$2/installed-files"
rsync_dir "$1/dots/.config/example" "$2/config-copy"
''', 'fixture', str(self.source), str(self.base)])
        self.assertTrue((self.base / 'config-copy/tools/tool.txt').is_file())

    def test_reject_escaping_symlinks_before_copy(self):
        outside = self.base / 'private-file'
        outside.write_text('EXCLUDED_SENTINEL')
        (self.source / 'scripts/leak').symlink_to(outside)
        with self.assertRaises(ValueError):
            self.payload.sync(self.target)
        self.assertFalse(self.target.exists())

    def test_reject_absolute_unshipped_and_directory_links(self):
        self.put('docs/not-installed.txt', 'EXCLUDED_SENTINEL')
        for destination in [str(self.source / 'modules/Live.qml'), '../docs/not-installed.txt']:
            link = self.source / 'scripts/leak'
            link.symlink_to(destination)
            with self.assertRaises(ValueError):
                self.payload.sync(self.target)
            self.assertFalse(self.target.exists())
            link.unlink()
        shutil.rmtree(self.source / 'modules')
        (self.source / 'modules').symlink_to('services', target_is_directory=True)
        with self.assertRaises(ValueError):
            self.payload.sync(self.target)
        self.assertFalse(self.target.exists())

    def test_directory_installer_rejects_escaping_link(self):
        outside = self.base / 'private-file'
        outside.write_text('EXCLUDED_SENTINEL')
        (self.source / 'scripts/leak').symlink_to(outside)
        result = subprocess.run(['bash', '-c', """
source "$1/sdata/lib/functions.sh"
x() { "$@"; }
INSTALLED_LISTFILE="$2/installed-files"
rsync_dir__sync "$1/scripts" "$2/installed/scripts"
""", 'fixture', str(self.source), str(self.base)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.target / 'scripts/leak').is_symlink())

    def test_orphan_filter_failure_propagates_without_cleanup(self):
        self.payload.sync(self.target)
        self.run_command(['python3', str(TOOL), 'manifest', '--root', str(self.source)])
        manifest = self.target / '.inir-manifest'
        manifest.write_text('shell.qml:\n')
        (self.source / 'sdata/runtime-exclusions.json').write_text('{invalid')
        result = subprocess.run(['bash', '-c', """
export REPO_ROOT="$1" XDG_CONFIG_HOME="$2/config" XDG_STATE_HOME="$2/state"
source "$1/sdata/lib/robust-update.sh"
log_info() { :; }
cleanup_orphans "$2/installed" "$2/installed/.inir-manifest"
""", 'fixture', str(self.source), str(self.base)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.target / 'modules/Live.qml').exists())

    def test_reject_source_and_nested_destinations(self):
        for target in [self.source, self.source / 'scripts/copy', self.base]:
            with self.assertRaises(ValueError):
                self.payload.sync(target)

    def test_make_install_shell(self):
        self.run_command(['make', '-f', str(ROOT / 'Makefile'), 'install-shell',
                          'SHELL_INSTALL_DIR=' + str(self.target)])
        self.assert_payload(self.target)
        self.assertTrue(os.access(self.target / "setup", os.X_OK))
        self.assertTrue(os.access(self.target / "scripts/inir", os.X_OK))

    def test_arch_package_functions(self):
        for name in ['LICENSE', 'NOTICE', 'README.md', 'docs/SETUP.md', 'docs/IPC.md', 'docs/GAME_PERFORMANCE.md',
                     'assets/systemd/inir.service', 'assets/applications/inir.desktop',
                     'assets/applications/inir-settings.desktop', 'assets/icons/desktop-symbolic.svg',
                     'distro/arch/inir-shell/inir-quickshell-rebuild.hook']:
            self.put(name, 'fixture\n')
        self.run_command(['git', 'init', '-q'])
        self.run_command(['git', 'add', 'VERSION'])
        self.run_command(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                          '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture'])
        for variant in ['inir-shell', 'inir-shell-git']:
            stage = self.base / variant
            self.run_command(['bash', '-c', '''
set -euo pipefail
source "$1"
srcdir="$2"
pkgdir="$3"
if [[ "$pkgname" == inir-shell ]]; then
  ln -s "$4" "$srcdir/iNiR-$pkgver"
else
  ln -s "$4" "$srcdir/inir"
fi
package
''', 'fixture', str(ROOT / 'distro/arch' / variant / 'PKGBUILD'), str(self.base), str(stage), str(self.source)])
            self.assert_payload(stage / 'usr/share/quickshell/inir')


if __name__ == '__main__':
    unittest.main(verbosity=2)
