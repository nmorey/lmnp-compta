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

class LaundryCommandTest < Minitest::Test
  TEST_DIR = File.join(__dir__, 'tmp', 'laundry_cmd')

  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
    @original_dir = Dir.pwd
    Dir.chdir(TEST_DIR)

    # Init project
    LMNPCompta::ConfigurerCommand.new(["init", "--siren", "123456789", "--annee", "2025"]).execute
    LMNPCompta::Settings.load('lmnp.yaml')
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_configurer_blanchisserie
    out, err = capture_io do
      LMNPCompta::ConfigurerCommand.new([
        "blanchisserie", "ajouter", "1",
        "--nom-bien", "Appart",
        "--conso-eau", "0.05",
        "--prix-eau", "4.0",
        "--conso-kwh", "1.0",
        "--prix-kwh", "0.25",
        "--prix-produit", "0.5"
      ]).execute
    end
    assert_match /Configuration blanchisserie ajoutée/, out

    out_list, err_list = capture_io do
      LMNPCompta::ConfigurerCommand.new(["blanchisserie", "lister"]).execute
    end
    assert_match /Appart/, out_list
    assert_match /0.95 € \/ lessive/, out_list
  end

  def test_journal_blanchisserie
    # Setup config
    LMNPCompta::ConfigurerCommand.new([
      "blanchisserie", "ajouter", "1",
      "--nom-bien", "Appart",
      "--conso-eau", "0", "--prix-eau", "0",
      "--conso-kwh", "0", "--prix-kwh", "0",
      "--prix-produit", "2.5"
    ]).execute

    out, err = capture_io do
      LMNPCompta::JournalCommand.new(["blanchisserie", "ajouter", "1", "2025-05-15"]).execute
    end
    assert_match /Frais de blanchisserie ajouté/, out

    # Verify journal content
    journal_file = 'data/2025/journal.yaml'
    entries = YAML.load_file(journal_file)
    assert_equal 1, entries.length
    assert_equal "LNDRY-1-20250515", entries[0]['ref']
    assert_equal "2,50", entries[0]['lignes'][0]['debit'] # Assumes Montant format
    assert_equal "615000", entries[0]['lignes'][0]['compte']
  end
end
