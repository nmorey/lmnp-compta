require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require 'date'

# Add lib to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'lmnp_compta'
require 'lmnp_compta/command'
require 'lmnp_compta/settings'
# require 'lmnp_compta/commands/import_airbnb' # Removed
# require 'lmnp_compta/commands/init' # Removed
require 'lmnp_compta/commands/journal'
require 'lmnp_compta/commands/configurer'

class AirbnbCommandTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'airbnb_cmd')
    FIXTURES_DIR = File.expand_path('fixtures', __dir__)

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @original_dir = Dir.pwd
        Dir.chdir(TEST_DIR)

        # Init project
        LMNPCompta::ConfigurerCommand.new(["init", "--siren", "123456789", "--annee", "2025"]).execute
        LMNPCompta::Settings.load('lmnp.yaml')

        # Create dummy CSV
        @csv_file = "airbnb.csv"
        csv_content = <<~CSV
          Type,Date,Code de confirmation,Date de début,Date de départ,Nuits,Hébergement,Ménage,Frais de service,Revenus bruts,Devise
          Payout,01/05/2025,,,,,,,,,
          Réservation,01/01/2025,REF001,01/01/2025,01/05/2025,4,Appart Paris,,0.00,100.00,EUR
        CSV
        File.write(@csv_file, csv_content)
    end

    def teardown
        Dir.chdir(@original_dir)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_dry_run_option
        # Ensure journal is empty
        journal_file = 'data/2025/journal.yaml'
        assert !File.exist?(journal_file) || YAML.load_file(journal_file).empty?

        # Execute with --dry-run
        out, err = capture_io do
            LMNPCompta::JournalCommand.new(["importer-airbnb", "-f", @csv_file, "--dry-run"]).execute
        end

        # Verify Output (Updated messages for JournalCommand)
        assert_match /Simulation/, out
        assert_match /REF001-01/, out
        assert_match /Simulation terminée/, out

        # Verify Journal NOT saved/updated
        journal = LMNPCompta::Journal.new(journal_file)
        assert_empty journal.entries
    end

    def test_normal_run
        # Execute without --dry-run
        out, err = capture_io do
            LMNPCompta::JournalCommand.new(["importer-airbnb", "-f", @csv_file]).execute
        end

        assert_match /Importation terminée. 1 écritures générées/, out
        assert_match /Journal sauvegardé/, out

        # Verify Journal Saved
        journal = LMNPCompta::Journal.new('data/2025/journal.yaml')
        assert_equal 1, journal.entries.length
        assert_equal "REF001-01", journal.entries.first.ref
    end

    def test_blanchisserie_import
        # Add laundry configuration
        LMNPCompta::ConfigurerCommand.new([
          "blanchisserie", "ajouter", "1",
          "--nom-bien", "Appart Paris",
          "--conso-eau", "0.05",
          "--prix-eau", "4.0",
          "--conso-kwh", "1.0",
          "--prix-kwh", "0.25",
          "--prix-produit", "0.5"
        ]).execute

        # Import with blanchisserie (dry-run should show it)
        out, err = capture_io do
          LMNPCompta::JournalCommand.new(["importer-airbnb", "-f", @csv_file, "--dry-run", "--blanchisserie", "1"]).execute
        end

        assert_match /Blanchisserie - Appart Paris \(LNDRY-REF001\)/, out

        # Import without dry-run
        capture_io do
          LMNPCompta::JournalCommand.new(["importer-airbnb", "-f", @csv_file, "--blanchisserie", "1"]).execute
        end

        # Verify Journal Entries
        journal = LMNPCompta::Journal.new('data/2025/journal.yaml')
        assert_equal 2, journal.entries.length

        # Original Entry
        assert_equal "REF001-01", journal.entries.first.ref

        # Laundry Entry
        laundry_entry = journal.entries.last
        assert_equal "LNDRY-REF001", laundry_entry.ref
        assert_equal "Blanchisserie - Appart Paris", laundry_entry.libelle
        assert_equal "0,95", laundry_entry.lines.first[:debit].to_s
    end
end