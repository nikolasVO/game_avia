import unittest

from budget_math import within_triangle_budget


class TriangleBudgetTests(unittest.TestCase):
    def test_5000_accepted(self):
        self.assertTrue(within_triangle_budget(5000))

    def test_5001_rejected(self):
        self.assertFalse(within_triangle_budget(5001))


if __name__ == "__main__":
    unittest.main()
