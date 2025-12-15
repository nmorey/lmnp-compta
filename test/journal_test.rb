require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/lmnp_compta/journal'
require_relative '../lib/lmnp_compta/entry'

class JournalTest < Minitest::Test
    TEST_JOURNAL = 'tmp_test/test_journal.yaml'

    def setup
        FileUtils.mkdir_p('tmp_test')
        FileUtils.rm_f(TEST_JOURNAL)
    end

    def teardown
        FileUtils.rm_rf('tmp_test')
    end

    def test_enforces_year
        journal = LMNPCompta::Journal.new(TEST_JOURNAL, year: 2025)

        # Valid entry
        entry_ok = LMNPCompta::Entry.new(date: "2025-05-01", journal: "OD", libelle: "OK")
        entry_ok.add_debit("600", 10); entry_ok.add_credit("512", 10)
        journal.add_entry(entry_ok)
        assert_equal 1, journal.entries.size

        # Invalid year
        entry_bad = LMNPCompta::Entry.new(date: "2024-12-31", journal: "OD", libelle: "Old")
        entry_bad.add_debit("600", 10); entry_bad.add_credit("512", 10)

        err = assert_raises(RuntimeError) { journal.add_entry(entry_bad) }
        assert_match /Date mismatch/, err.message
    end

    def test_no_year_enforcement
        journal = LMNPCompta::Journal.new(TEST_JOURNAL) # year nil

        entry_2024 = LMNPCompta::Entry.new(date: "2024-12-31", journal: "OD", libelle: "Old")
        entry_2024.add_debit("600", 10); entry_2024.add_credit("512", 10)

        journal.add_entry(entry_2024)
        assert_equal 1, journal.entries.size
    end
end
