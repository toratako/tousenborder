"""Authoring contract for beginner support, independent of UI and generated prose."""
import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from build_problem_catalog import read_json, resource_path, validate_authoring, validate_schema


class LearningSupportTests(unittest.TestCase):
    def setUp(self):
        self.pack = read_json(ROOT / 'tests/fixtures/learning-support/pack.json')
        self.item = read_json(ROOT / 'tests/fixtures/learning-support/problem.json')

    def test_support_fixture_validates(self):
        validate_authoring(self.item, self.pack)

    def test_unknown_or_duplicate_term_is_rejected(self):
        for mode in ('unknown', 'duplicate'):
            item = copy.deepcopy(self.item)
            if mode == 'unknown':
                item['glossary'][0]['term_id'] = 'not_a_term'
            else:
                item['glossary'].append(copy.deepcopy(item['glossary'][0]))
            with self.assertRaises(ValueError):
                validate_authoring(item, self.pack)

    def test_occurrence_contract(self):
        for occurrence in [
            {'source_id': 'missing', 'section': 'result'},
            {'source_id': 'sha256sum', 'section': 'initial'},
            {'source_id': 'initial_information', 'section': 'result'},
            {'source_id': 'vendor_hash', 'section': 'submission'},
            {'source_id': 'sha256sum', 'section': 'unknown'},
        ]:
            item = copy.deepcopy(self.item)
            item['glossary'][0]['occurrences'] = [occurrence]
            with self.assertRaises(ValueError):
                validate_authoring(item, self.pack)
        item = copy.deepcopy(self.item)
        item['glossary'][0]['occurrences'] *= 2
        with self.assertRaises(ValueError):
            validate_authoring(item, self.pack)

    def test_dictionary_required_only_when_terms_are_used(self):
        pack = copy.deepcopy(self.pack)
        del pack['glossary_path']
        with self.assertRaises(ValueError):
            validate_authoring(self.item, pack)
        item = copy.deepcopy(self.item)
        del item['glossary']
        validate_authoring(item, pack)

    def test_unknown_dictionary_fields_rejected(self):
        with self.assertRaises(ValueError):
            validate_schema({'schema_version': 1, 'terms': {'x': {'label': 'X', 'description': 'Y', 'answer': 'block'}}}, 'glossary')


class StandardGlossaryTests(unittest.TestCase):
    """Content regressions: similar words must not reveal unrelated evidence."""

    def glossary(self, problem_id):
        item = read_json(ROOT / 'data/problems' / f'{problem_id}.json')
        return {entry['term_id']: entry['occurrences'] for entry in item['glossary']}

    def test_standard_pack_has_glossary_for_every_problem(self):
        pack = read_json(ROOT / 'data/packs/learning.json')
        self.assertEqual(pack['glossary_path'], 'res://data/glossary/security.json')
        for path in pack['problems']:
            with self.subTest(path=path):
                item = read_json(resource_path(path))
                self.assertTrue(item['glossary'])
                validate_authoring(item, pack)

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
