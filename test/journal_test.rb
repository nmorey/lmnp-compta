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
        assert_match /Erreur de date/, err.message
    end

    def test_no_year_enforcement
        journal = LMNPCompta::Journal.new(TEST_JOURNAL) # year nil

        entry_2024 = LMNPCompta::Entry.new(date: "2024-12-31", journal: "OD", libelle: "Old")
        entry_2024.add_debit("600", 10); entry_2024.add_credit("512", 10)

        journal.add_entry(entry_2024)
        assert_equal 1, journal.entries.size
    end

    # Test select method filters entries using the provided block.
    #
    # @return [void]
    def test_select
        journal = LMNPCompta::Journal.new(TEST_JOURNAL)

        entry1 = LMNPCompta::Entry.new(date: "2025-05-01", journal: "VT", libelle: "Rent May", ref: "REF01")
        entry1.add_debit("512", 10); entry1.add_credit("706", 10)
        journal.add_entry(entry1)

        entry2 = LMNPCompta::Entry.new(date: "2025-06-01", journal: "VT", libelle: "Rent June", ref: "REF02")
        entry2.add_debit("512", 20); entry2.add_credit("706", 20)
        journal.add_entry(entry2)

        selected = journal.select { |e| e.libelle.include?("Rent June") }
        assert_equal 1, selected.length
        assert_equal "Rent June", selected.first.libelle

        ref_selected = journal.select { |e| e.ref =~ /^REF/ }
        assert_equal 2, ref_selected.length
    end

    # Test LMNPCompta.confirm! helper when STDIN is a TTY and user says yes.
    #
    # @return [void]
    def test_confirmation_helper_tty_yes
        $stdin.stub(:tty?, true) do
            $stdin.stub(:gets, "y\n") do
                LMNPCompta.confirm!("Are you sure?") # Should not raise
            end
        end
    end

    # Test LMNPCompta.confirm! helper when STDIN is a TTY and user says no.
    #
    # @raise [LMNPCompta::UserCancelledError]
    # @return [void]
    def test_confirmation_helper_tty_no
        $stdin.stub(:tty?, true) do
            $stdin.stub(:gets, "n\n") do
                assert_raises(LMNPCompta::UserCancelledError) do
                    LMNPCompta.confirm!("Are you sure?")
                end
            end
        end
    end

    # Test LMNPCompta.confirm! helper when STDIN is not a TTY.
    #
    # @return [void]
    def test_confirmation_helper_non_tty
        $stdin.stub(:tty?, false) do
            LMNPCompta.confirm!("Are you sure?") # Should not raise
        end
    end

    # Test that save! in maintenance mode prompts for confirmation and aborts on No.
    #
    # @return [void]
    def test_save_in_maintenance_mode_aborts
        journal = LMNPCompta::Journal.new(TEST_JOURNAL, maintenance: true)
        entry = LMNPCompta::Entry.new(date: "2025-05-01", journal: "VT", libelle: "Rent")
        entry.add_debit("512", 10); entry.add_credit("706", 10)
        journal.add_entry(entry)

        # Stub STDIN to pretend it is a TTY and user says no
        $stdin.stub(:tty?, true) do
            $stdin.stub(:gets, "n\n") do
                assert_raises(LMNPCompta::UserCancelledError) do
                    journal.save!
                end
            end
        end
    end

    # Test that save! in maintenance mode prompts for confirmation and succeeds on Yes.
    #
    # @return [void]
    def test_save_in_maintenance_mode_succeeds
        journal = LMNPCompta::Journal.new(TEST_JOURNAL, maintenance: true)
        entry = LMNPCompta::Entry.new(date: "2025-05-01", journal: "VT", libelle: "Rent")
        entry.add_debit("512", 10); entry.add_credit("706", 10)
        journal.add_entry(entry)

        # Stub STDIN to pretend it is a TTY and user says yes
        $stdin.stub(:tty?, true) do
            $stdin.stub(:gets, "y\n") do
                journal.save! # Should succeed and write to disk
            end
        end
        assert File.exist?(TEST_JOURNAL)
    end
end
