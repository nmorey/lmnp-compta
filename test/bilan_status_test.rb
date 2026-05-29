require 'minitest/autorun'
require 'fileutils'
require 'stringio'
require 'yaml'
require_relative '../lib/lmnp_compta'
require_relative '../lib/lmnp_compta/commands/bilan'
require_relative '../lib/lmnp_compta/commands/bilan/status'
require_relative '../lib/lmnp_compta/settings'

class BilanStatusTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'bilan_status')
    CONFIG_FILE = File.join(TEST_DIR, 'lmnp.yaml')
    JOURNAL_FILE = File.join(TEST_DIR, '2025', 'journal.yaml')
    IMMO_FILE = File.join(TEST_DIR, 'immobilisations.yaml')
    STOCK_FILE = File.join(TEST_DIR, 'stock_fiscal.yaml')

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(File.join(TEST_DIR, '2025'))

        # Create config file
        File.write(CONFIG_FILE, <<~YAML)
            siren: "123456789"
            annee: 2025
            data_dir: "#{TEST_DIR}"
            journal_file: "journal.yaml"
            immo_file: "immobilisations.yaml"
            stock_file: "stock_fiscal.yaml"
        YAML

        # Force load settings
        LMNPCompta::Settings.load(CONFIG_FILE)

        # Create journal with initial entries
        journal = LMNPCompta::Journal.new(JOURNAL_FILE, year: 2025)

        # Entry 1: Loyer (Bank debit 512, Income credit 706)
        e1 = LMNPCompta::Entry.new(date: "2025-01-15", libelle: "Loyer Janvier", ref: "REF001")
        e1.add_debit("512000", "1200.00")
        e1.add_credit("706000", "1200.00")
        journal.add_entry(e1)

        # Entry 2: Charges (Bank credit 512, Expenses debit 615)
        e2 = LMNPCompta::Entry.new(date: "2025-02-20", libelle: "Réparations", ref: "REF002")
        e2.add_credit("512000", "200.00")
        e2.add_debit("615000", "200.00")
        journal.add_entry(e2)

        journal.save!

        # Create immobilisations
        File.write(IMMO_FILE, [
            {
                'nom' => 'Appartement',
                'date_mise_en_location' => '2025-01-01',
                'composants' => [
                    { 'nom' => 'Mobilier', 'valeur' => 5000, 'duree' => 5 }
                ]
            }
        ].to_yaml)
    end

    def teardown
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_status_simulation_mode
        # Verify initial files exist
        assert File.exist?(JOURNAL_FILE)
        assert File.exist?(IMMO_FILE)
        refute File.exist?(STOCK_FILE)

        # Capture output from the simulation
        out, err = capture_io do
            LMNPCompta::Commands::Bilan::Status.new([]).execute
        end

        # Check stdout outputs simulation header
        assert_match /\[SIMULATION\] CLÔTURE DE L'EXERCICE 2025/, out
        assert_match /\[SIMULATION\] GÉNÉRATION DE LA LIASSE/, out

        # Check closing step outputs are present
        assert_match /--- 1. Calcul des Amortissements ---/, out
        assert_match /✅ Écriture de dotation générée : 1000,00 €/, out
        assert_match /--- 2. Calcul des Indemnités Kilométriques ---/, out
        assert_match /--- 3. Solde de Trésorerie ---/, out
        assert_match /Solde actuel 512000 : 1000,00 €/, out
        assert_match /👉 Virement du surplus vers compte personnel./, out
        assert_match /✅ Écriture de solde générée./, out

        # Check liasse report contains simulated figures:
        # Total CA = 1200. Charges externes = 200. Dotations = 1000.
        # Résultat = 1200 - 1200 = 0.
        assert_match /Chiffre d'affaires \(Loyers\)\s+:\s+1200 €/, out
        assert_match /Dotations aux amortissements\s+:\s+1000 €/, out
        assert_match /Résultat fiscal \(Bénéfice\)\s+:\s+0 €/, out

        # Verify that journal file on disk is UNMODIFIED (only has original 2 entries)
        disk_journal = YAML.load_file(JOURNAL_FILE)
        assert_equal 2, disk_journal.length
        refute disk_journal.any? { |e| e['ref'] == 'DOTA2025' }
        refute disk_journal.any? { |e| e['ref'] == 'CLOTURE2025' }

        # Verify that next year's stock file was NOT created/written to disk
        next_year_stock_file = File.join(TEST_DIR, '2026', 'stock_fiscal.yaml')
        refute File.exist?(next_year_stock_file), "Stock file for next year should not be created by status"
    end
end
