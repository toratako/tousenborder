"""Location-specific glossary regressions: unrelated evidence stays hidden."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read_json(path):
    return json.loads(path.read_text())

class StandardGlossaryTests(unittest.TestCase):
    """Content regressions: similar words must not reveal unrelated evidence."""

    def glossary(self, problem_id):
        path = ROOT / 'data/problems' / f'{problem_id}.json'
        if not path.exists():
            path = ROOT / 'authoring/archive/problems' / f'{problem_id}.json'
        item = read_json(path)
        locations = {}
        blocks = [('initial_information', 'initial', item['initial'])]
        for resource in item['resources']:
            blocks += [(resource['id'], 'overview', resource), (resource['id'], 'result', resource['result'])]
            if 'submission' in resource:
                blocks.append((resource['id'], 'submission', resource['submission']))
        for source, section, block in blocks:
            for term in block.get('terms', []):
                locations.setdefault(term, []).append({'source_id': source, 'section': section})
        return locations

    def test_published_terms_have_definitions(self):
        terms = read_json(ROOT / 'data/glossary/security.json')['terms']
        for path in (ROOT / 'data/problems').glob('*.json'):
            mapping = self.glossary(path.stem)
            self.assertTrue(mapping)
            self.assertTrue(set(mapping) <= terms.keys(), path.stem)

    def test_revocation_and_log_events_require_their_evidence(self):
        entries = self.glossary('AUTH-WIN-REVOKED-DEVICE')
        self.assertEqual(entries['active_revoked'], [{'source_id': 'device', 'section': 'result'}])
        self.assertEqual(entries['event_id'], [{'source_id': 'events', 'section': 'result'}])

    def test_lastlog_port_is_a_terminal_not_a_network_port(self):
        entries = self.glossary('AUTH-LINUX-BASTION-LOGIN')
        self.assertIn({'source_id': 'lastlog', 'section': 'result'}, entries['terminal'])
        self.assertNotIn({'source_id': 'lastlog', 'section': 'result'}, entries.get('port', []))
        self.assertNotIn('reply_to', entries)

    def test_package_resolver_is_not_dns(self):
        entries = self.glossary('PKG-PYPI-DEPENDENCY-CONFUSION')
        self.assertIn('package_resolver', entries)
        self.assertNotIn('dns_resolver', entries)
        self.assertNotIn('terminal', entries)  # scripts/ is not pts/.

    def test_filenames_and_commands_do_not_add_unrelated_terms(self):
        entries = self.glossary('FILE-WIN-PUBLISHED-HASH')
        self.assertIn('tool_hash_win', entries)
        self.assertNotIn('http_method', entries)  # Get-FileHash is not HTTP GET.
        self.assertNotIn('lock_file', entries)  # BLOCK is not a Lock File.
        entries = self.glossary('PROC-WIN-SYSTEM-NAME')
        self.assertIn('system_account', entries)
        self.assertNotIn('host', entries)  # svchost.exe is not a Host field.

    def test_elf_details_are_available_only_after_reading_results(self):
        entries = self.glossary('FILE-LINUX-STRIPPED-INTERNAL')
        self.assertTrue(entries['stripped'])
        self.assertTrue(all(o['section'] == 'result' for o in entries['stripped']))
        self.assertNotIn('system_account', entries)


if __name__ == '__main__':
    unittest.main()
