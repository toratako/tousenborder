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


if __name__ == '__main__':
    unittest.main()
