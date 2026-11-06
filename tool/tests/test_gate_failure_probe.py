"""Temporary intentional failure used to verify the GitHub merge gate."""

import unittest


class MergeGateProbe(unittest.TestCase):
    def test_intentional_failure(self):
        self.fail("Intentional Phase 5 merge gate verification failure")
