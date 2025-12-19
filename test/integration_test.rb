require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'date'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'lmnp_compta'
require 'lmnp_compta/command'
require 'lmnp_compta/settings'

# Load all commands
Dir.glob(File.join(__dir__, '../lib/lmnp_compta/commands/*.rb')).each do |file|
    require file
end

class IntegrationTest < Minitest::Test
    TEST_DIR = File.expand_path('tmp_test', __dir__)
    FIXTURES_DIR = File.expand_path('fixtures', __dir__)

    def setup
        # Cleanup and create test dir
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)

        # Switch to test directory
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # 0. Init Project
        puts "\n--- Test: Init ---"
        args_init = ["--siren", "123456789", "--annee", "2025"]
        LMNPCompta::Commands::Init.new(args_init).execute

        assert File.exist?('lmnp.yaml'), "lmnp.yaml should be created by init command"

        # Mock Settings to reload the new file
        LMNPCompta::Settings.load('lmnp.yaml')

        # Copy fixtures
        # `lmnp init` creates 'data/' dir, so we can copy into it
        FileUtils.cp(File.join(FIXTURES_DIR, 'immobilisations.yaml'), 'data/immobilisations.yaml')
        FileUtils.cp(File.join(FIXTURES_DIR, 'airbnb_anonymized.csv'), 'airbnb.csv')
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_full_workflow
        # 1. Import Airbnb
        puts "\n--- Test: Import Airbnb ---"
        args = ["-f", "airbnb.csv"]
        LMNPCompta::Commands::ImportAirbnb.new(args).execute

        assert File.exist?('data/2025/journal.yaml'), "Journal file should be created"
        journal = YAML.load_file('data/2025/journal.yaml')
        assert_equal 2, journal.length, "Should have imported 2 entries"
        assert_equal "Airbnb - RESA001-01 (Période 05/01 - 04/01)", journal.first['libelle']
        # Check amount parsing (RESA001: 515.00 Brut, 15.00 Com, 500.00 Net)
        # Entry 1:
        # Credit 706000: 515.00
        # Debit 622600: 15.00
        # Debit 512000: 500.00

        entry1 = journal.find { |e| e['ref'] == 'RESA001-01' }
        l_rev = entry1['lignes'].find { |l| l['compte'] == '706000' }
        l_com = entry1['lignes'].find { |l| l['compte'] == '622600' }
        l_ban = entry1['lignes'].find { |l| l['compte'] == '512000' }

        assert_equal "515,00", l_rev['credit']
        assert_equal "15,00", l_com['debit']
        assert_equal "500,00", l_ban['debit']

        # Test for Add Entry CLI
        puts "\n--- Test: Add Entry CLI ---"
        args_add_entry = [
            "-d", "27/01/2025",
            "-j", "AC",
            "-l", "Charges Copro (Appel 1/2025)",
            "-r", "Appel 01/02/2025",
            "-c", "614000", "-s", "D", "-m", "302.01",
            "-c", "512000", "-s", "C", "-m", "302.01" # Assuming 512000 is the correct bank account
        ]
        LMNPCompta::Commands::AddEntry.new(args_add_entry).execute

        journal = YAML.load_file('data/2025/journal.yaml')
        entry_copro = journal.find { |e| e['libelle'] == "Charges Copro (Appel 1/2025)" }
        assert entry_copro, "Copro entry should exist"
        assert_equal "2025-01-27", entry_copro['date']
        assert_equal "AC", entry_copro['journal']
        assert_equal "Appel 01/02/2025", entry_copro['ref']
        assert_equal 2, entry_copro['lignes'].length

        l_debit = entry_copro['lignes'].find { |l| l['compte'] == '614000' }
        l_credit = entry_copro['lignes'].find { |l| l['compte'] == '512000' }

        assert_equal "302,01", l_debit['debit']
        assert_nil l_debit['credit']
        assert_equal "302,01", l_credit['credit']
        assert_nil l_credit['debit']

        # Update expected journal length for subsequent tests
        # 2 Airbnb + 1 Copro = 3
        assert_equal 3, journal.length, "Journal should now have 3 entries (2 Airbnb + 1 Copro)"

        # 2. Amortize
        puts "\n--- Test: Amortize ---"
        LMNPCompta::Commands::Amortize.new([]).execute

        journal = YAML.load_file('data/2025/journal.yaml')
        entry_amort = journal.find { |e| e['ref'] == 'DOTA2025' }
        assert entry_amort, "Amortization entry should exist"

        # Calculate expected amortization
        # Gros Oeuvre: 60000 / 50 = 1200
        # Façade: 15000 / 20 = 750
        # Installations: 20000 / 15 = 1333.33
        # Agencements: 15000 / 15 = 1000
        # Mobilier: 10000 / 10 = 1000
        # Total = 1200 + 750 + 1333.33 + 1000 + 1000 = 5283.33

        l_dot = entry_amort['lignes'].find { |l| l['compte'] == '681100' }
        assert_equal "5283,33", l_dot['debit']

        # 3. Close Year (Clôture)
        puts "\n--- Test: Close Year ---"
        # Current Bank Balance:
        # +500.00 (Airbnb 1)
        # +950.50 (Airbnb 2)
        # = 1450.50
        # So we expect a Debit of 108000 and Credit of 512000 for 1450.50

        LMNPCompta::Commands::CloseYear.new([]).execute

        journal = YAML.load_file('data/2025/journal.yaml')
        entry_close = journal.find { |e| e['ref'] == 'CLOTURE2025' }
        assert entry_close, "Closure entry should exist"

        l_bq = entry_close['lignes'].find { |l| l['compte'] == '512000' }
        assert_equal "1148,49", l_bq['credit']

        # 4. Report (Liasse)
        puts "\n--- Test: Report (Liasse) ---"
        # Create dummy stock file if not exists (handled by code but good to verify)
        LMNPCompta::Commands::Report.new([]).execute

        assert File.exist?('data/2026/stock_fiscal.yaml'), "Stock file should be created/updated"
        stock = LMNPCompta::Stock.load('data/2026/stock_fiscal.yaml')
        # Verify stock ARD/Deficit logic
        # Recettes: 515 + 981 = 1496.00
        # Charges: 15 + 30.50 = 45.50
        # Resultat avant amort: 1496 - 45.50 = 1450.50
        # Dotations: 5283.33
        # Benefice (Limite deduc): 1450.50
        # Amort deduct: 1450.50
        # ARD Cree: 5283.33 - 1148.49 = 4134.84

        assert_in_delta 4134,84, stock.ard, 0.01

        # 5. Export FEC
        puts "\n--- Test: Export FEC ---"
        LMNPCompta::Commands::ExportFEC.new([]).execute
        fec_filename = "data/2025/123456789FEC20251231.txt"
        assert File.exist?(fec_filename), "FEC file should be created"

        content = File.read(fec_filename)
        assert_match /JournalCode\tJournalLib/, content
        assert_match /Airbnb - RESA001/, content
    end

    def test_importer_facture_unknown_invoice_output_format
        puts "\n--- Test: Import Unknown Invoice Output ---"

        # Create a dummy unknown PDF file
        File.write("unknown_invoice.pdf", "This is not a real PDF invoice.")

        # Capture output from the command
        out, err = capture_io do
            LMNPCompta::Commands::ImportInvoice.new(["unknown_invoice.pdf"]).execute
        end

        # Assert that every non-empty line in the output starts with '#'
        non_empty_lines = out.strip.split("\n").reject(&:empty?)
        assert non_empty_lines.any?, "Output should not be empty"
        non_empty_lines.each do |line|
            assert_match /^#/, line, "Line '#{line}' does not start with '#'"
        end

        # Also check stderr, as some parsing errors might go there
        # For now, let's assume all relevant output goes to stdout.
        # If the actual implementation puts non-#-prefixed errors to stderr, this might need adjustment.
        # However, the user specifically mentioned "output can be executed by a shell script",
        # which implies stdout should be clean or commented.
        assert err.empty?, "Stderr should be empty for a clean output."

    end
end
