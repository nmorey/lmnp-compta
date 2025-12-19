require 'minitest/autorun'
require 'stringio'
require 'fileutils'
require_relative '../lib/lmnp_compta/commands/status'
require_relative '../lib/lmnp_compta/journal'
require_relative '../lib/lmnp_compta/settings'

class StatusCommandTest < Minitest::Test
    TEST_DIR = 'tmp_test_status'
    CONFIG_FILE = File.join(TEST_DIR, 'lmnp.yaml')
    JOURNAL_FILE = File.join(TEST_DIR, '2025', 'journal.yaml')

    def setup
        FileUtils.mkdir_p(File.dirname(JOURNAL_FILE))

        # Create config file
        File.write(CONFIG_FILE, <<~YAML)
            siren: "123456789"
            annee: 2025
            data_dir: "#{TEST_DIR}"
            journal_file: "journal.yaml"
        YAML

        # Load settings
        LMNPCompta::Settings.load(CONFIG_FILE)

        # Create journal with sample data
        journal = LMNPCompta::Journal.new(JOURNAL_FILE, year: 2025)

        # Entry 1: Income (Debit 512) - Should appear
        e1 = LMNPCompta::Entry.new(date: "2025-01-15", libelle: "Loyer Janvier", ref: "REF001")
        e1.add_debit("512000", "500.00")
        e1.add_credit("706000", "500.00")
        journal.add_entry(e1)

        # Entry 2: Expense (Credit 512) - Should appear
        e2 = LMNPCompta::Entry.new(date: "2025-02-20", libelle: "Facture EDF", ref: "REF002")
        e2.add_credit("512000", "50.00")
        e2.add_debit("606100", "50.00")
        journal.add_entry(e2)

        # Entry 3: Non-bank transaction - Should NOT appear
        e3 = LMNPCompta::Entry.new(date: "2025-03-01", libelle: "Amortissement", ref: "REF003")
        e3.add_debit("681100", "100.00")
        e3.add_credit("281000", "100.00")
        journal.add_entry(e3)

        # Entry 4: Wrong year - Should NOT appear
        # Note: Journal enforces year if set, so we force inject or create separate journal?
        # Journal.add_entry checks year.
        # But StatusCommand filters by year from Settings.
        # If I want to test year filtering, I need an entry with a different year in the file.
        # But Journal implementation prevents adding wrong year if initialized with year.
        # So I'll append directly to the YAML file to simulate a "dirty" or multi-year file if that were possible,
        # OR just re-open journal without year constraint.
        journal.save!

        # Add a 2024 entry bypassing constraint (re-open without year)
        j_mixed = LMNPCompta::Journal.new(JOURNAL_FILE) # year nil
        e4 = LMNPCompta::Entry.new(date: "2024-12-31", libelle: "Vieux Loyer", ref: "REFOLD")
        e4.add_debit("512000", "500.00")
        e4.add_credit("706000", "500.00")
        j_mixed.add_entry(e4)
        j_mixed.save!
    end

    def teardown
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_status_output
        # Capture stdout
        out, err = capture_io do
            LMNPCompta::StatusCommand.new([]).execute
        end

        # Verify Headers
        assert_match /Date\tRef\tCrédit\tDébit/, out

        # Verify Entry 1 (2025 Income)
        assert_match /2025-01-15\tREF001\t500,00\t""/, out

        # Verify Entry 2 (2025 Expense)
        assert_match /2025-02-20\tREF002\t""\t50,00/, out

        # Verify Entry 3 (Non-bank) NOT present
        refute_match /REF003/, out

        # Verify Entry 4 (Wrong year) NOT present
        refute_match /REFOLD/, out

        # Verify Summary Line
        # Total Solde = 500 - 50 = 450
        # Total Credit = 50
        # Total Debit = 500
        assert_match /Total \(Solde\): 450,00/, out
        assert_match /\t500,00\t50,00/, out
    end
end
