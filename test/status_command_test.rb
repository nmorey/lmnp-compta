require 'minitest/autorun'
require 'stringio'
require 'fileutils'
require_relative '../lib/lmnp_compta/commands/journal'
require_relative '../lib/lmnp_compta/journal'
require_relative '../lib/lmnp_compta/settings'

class StatusCommandTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'status')
    CONFIG_FILE = File.join(TEST_DIR, 'lmnp.yaml')
    JOURNAL_FILE = File.join(TEST_DIR, '2025', 'journal.yaml')

    def setup
        # Create a real file structure because Status reads files
        FileUtils.mkdir_p(File.join(TEST_DIR, '2025'))

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

        # Entry 5: Airbnb full earning
        e5 = LMNPCompta::Entry.new(date: "2025-04-01", libelle: "Airbnb", ref: "AIRBNB")
        e5.add_debit("512000", "400.00")
        e5.add_debit("622000", "100.00")
        e5.add_credit("706000", "500.00")
        journal.add_entry(e5)

        # Entry 6: Spending with discount
        e6 = LMNPCompta::Entry.new(date: "2025-05-01", libelle: "Achat matos", ref: "MATOS")
        e6.add_credit("512000", "90.00")
        e6.add_debit("606100", "100.00")
        e6.add_credit("768000", "10.00")
        journal.add_entry(e6)

        # Entry 7: 108000 valid
        e7 = LMNPCompta::Entry.new(date: "2025-06-01", libelle: "Apport perso", ref: "PERSO")
        e7.add_credit("108000", "300.00")
        e7.add_debit("606100", "300.00")
        journal.add_entry(e7)

        # Entry 8: 108000 with Immo (should be ignored)
        e8 = LMNPCompta::Entry.new(date: "2025-07-01", libelle: "Apport immo", ref: "PERSOIMMO")
        e8.add_credit("108000", "1000.00")
        e8.add_debit("218100", "1000.00")
        journal.add_entry(e8)

        # Entry 9: CLOTURE entry (should be ignored)
        e9 = LMNPCompta::Entry.new(date: "2025-12-31", libelle: "Virement solde trésorerie (Clôture)", ref: "CLOTURE2025")
        e9.add_debit("108000", "450.00")
        e9.add_credit("512000", "450.00")
        journal.add_entry(e9)

        # Wrong year - Should NOT appear
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
            LMNPCompta::JournalCommand.new(["status"]).execute
        end

        # Verify Headers
        assert_match /Date\s+Ref\s+Crédit\s+Débit/, out

        # Verify Entry 1 (2025 Income)
        assert_match /2025-01-15\s+REF001\s+\+500,00/, out

        # Verify Entry 2 (2025 Expense)
        assert_match /2025-02-20\s+REF002\s+-50,00/, out

        # Verify Entry 5 (2025 Airbnb Bank only)
        assert_match /2025-04-01\s+AIRBNB\s+\+400,00/, out

        # Verify Entry 6 (2025 Expense Bank only)
        assert_match /2025-05-01\s+MATOS\s+-90,00/, out

        # Verify Entry 7 (108000) NOT present in normal mode
        refute_match /PERSO\s/, out

        # Verify Entry 3 (Non-bank) NOT present
        refute_match /REF003/, out

        # Verify Entry 4 (Wrong year) NOT present
        refute_match /REFOLD/, out

        # Verify Summary Line
        # Total Crédit = 500 (E1) + 400 (E5) = 900
        # Total Débit = 50 (E2) + 90 (E6) = 140
        # Total Solde = 900 - 140 = 760
        assert_match /Solde: 💰 \+760,00/, out
        assert_match /Total\s+900,00\s+140,00/, out
    end

    def test_status_full_output
        # Capture stdout
        out, err = capture_io do
            LMNPCompta::JournalCommand.new(["status", "--full"]).execute
        end

        # Verify Headers
        assert_match /Date\s+Ref\s+Crédit\s+Débit/, out

        # Verify Entry 1 (2025 Income)
        assert_match /2025-01-15\s+REF001\s+\+500,00/, out

        # Verify Entry 2 (2025 Expense)
        assert_match /2025-02-20\s+REF002\s+-50,00/, out

        # Verify Entry 5 (2025 Airbnb full: 400 credit, 100 debit)
        assert_match /2025-04-01\s+AIRBNB\s+\+500,00\s+-100,00/, out

        # Verify Entry 6 (2025 Expense full: 10 credit, 90 debit)
        assert_match /2025-05-01\s+MATOS\s+\+10,00\s+-100,00/, out

        # Verify Entry 7 (108000 present: 0 credit, 300 debit)
        assert_match /2025-06-01\s+PERSO\s+-300,00/, out

        # Verify Entry 8 (108000 with immo) NOT present
        refute_match /PERSOIMMO/, out

        # Verify Entry 3 (Non-bank) NOT present
        refute_match /REF003/, out

        # Verify Entry 4 (Wrong year) NOT present
        refute_match /REFOLD/, out

        # Verify Summary Line
        # Total Crédit = 500 (E1) + 400 (E5) + 10 (E6) = 910
        # Total Débit = 50 (E2) + 100 (E5) + 90 (E6) + 300 (E7) = 540
        # Total Solde = 910 - 540 = 370
        assert_match /Solde: 💰 \+460,00/, out
        assert_match /Total\s+1010,00\s+550,00/, out
    end
end
