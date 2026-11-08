require 'minitest/autorun'
require 'fileutils'
require 'stringio'
require 'yaml'
require_relative '../lib/lmnp_compta/commands/journal/saisir'
require_relative '../lib/lmnp_compta/settings'

class SaisirCommandTest < Minitest::Test
  TEST_DIR = File.join(__dir__, 'tmp', 'saisir')
  CONFIG_FILE = File.join(TEST_DIR, 'lmnp.yaml')
  JOURNAL_FILE = File.join(TEST_DIR, '2025', 'journal.yaml')

  def setup
    FileUtils.rm_rf(TEST_DIR)
    FileUtils.mkdir_p(File.join(TEST_DIR, '2025'))

    File.write(CONFIG_FILE, <<~YAML)
      siren: "123456789"
      annee: 2025
      data_dir: "#{TEST_DIR}"
      journal_file: "journal.yaml"
    YAML

    LMNPCompta::Settings.load(CONFIG_FILE)
  end

  def teardown
    FileUtils.rm_rf(TEST_DIR)
  end

  def test_cli_mode_with_libelle_ligne
    args = [
      "-d", "2025-01-27",
      "-j", "AC",
      "-l", "Facture Fournitures",
      "-c", "606000", "-s", "D", "-m", "150.00", "-L", "Fournitures bureau",
      "-c", "512000", "-s", "C", "-m", "150.00", "--libelle-ligne", "Paiement banque"
    ]

    out, _ = capture_io do
      LMNPCompta::Commands::Journal::Saisir.new(args).execute
    end

    assert_match(/Mode Commande/, out)
    assert File.exist?(JOURNAL_FILE)

    journal = YAML.load_file(JOURNAL_FILE)
    assert_equal 1, journal.length

    entry = journal.first
    assert_equal "Facture Fournitures", entry['libelle']
    assert_equal 2, entry['lignes'].length

    l1 = entry['lignes'].find { |l| l['compte'] == '606000' }
    assert_equal "150,00", l1['debit']
    assert_equal "Fournitures bureau", l1['libelle_ligne']

    l2 = entry['lignes'].find { |l| l['compte'] == '512000' }
    assert_equal "150,00", l2['credit']
    assert_equal "Paiement banque", l2['libelle_ligne']
  end

  def test_cli_mode_with_libelle_line_alias_and_flag_order
    args = [
      "-d", "2025-01-27",
      "-j", "AC",
      "-l", "Facture Diverse",
      "-c", "606000", "--libelle-line", "Ligne d'achat", "-s", "D", "-m", "50.00",
      "-c", "512000", "-m", "50.00", "-s", "C"
    ]

    capture_io do
      LMNPCompta::Commands::Journal::Saisir.new(args).execute
    end

    journal = YAML.load_file(JOURNAL_FILE)
    entry = journal.first
    l1 = entry['lignes'].find { |l| l['compte'] == '606000' }
    assert_equal "Ligne d'achat", l1['libelle_ligne']

    l2 = entry['lignes'].find { |l| l['compte'] == '512000' }
    assert_nil l2['libelle_ligne']
  end

  def test_line_field_before_compte_raises_error
    args = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-s", "D", "-c", "606000", "-m", "50.00"
    ]

    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args).execute
    end
    assert_match(/Ligne non initialisée/, err.message)
  end

  def test_libelle_ligne_before_compte_raises_error
    args = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-L", "Ligne", "-c", "606000", "-s", "D", "-m", "50.00"
    ]

    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args).execute
    end
    assert_match(/Ligne non initialisée/, err.message)
  end

  def test_duplicate_line_fields_raise_error
    args_sens = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-c", "606000", "-s", "D", "-s", "C"
    ]
    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args_sens).execute
    end
    assert_match(/Sens déjà spécifié/, err.message)

    args_montant = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-c", "606000", "-m", "10", "-m", "20"
    ]
    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args_montant).execute
    end
    assert_match(/Montant déjà spécifié/, err.message)

    args_libelle = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-c", "606000", "-L", "A", "-L", "B"
    ]
    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args_libelle).execute
    end
    assert_match(/Libellé de ligne déjà spécifié/, err.message)
  end

  def test_incomplete_line_raises_error
    args_mid = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-c", "606000", "-s", "D",
      "-c", "512000", "-s", "C", "-m", "50"
    ]
    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args_mid).execute
    end
    assert_match(/Ligne incomplète/, err.message)

    args_end = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-c", "606000", "-s", "D", "-m", "50",
      "-c", "512000"
    ]
    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args_end).execute
    end
    assert_match(/Ligne incomplète/, err.message)
  end

  def test_invalid_sens_raises_error
    args = [
      "-d", "2025-01-27", "-j", "AC", "-l", "Test",
      "-c", "606000", "-s", "X", "-m", "50"
    ]
    err = assert_raises(RuntimeError) do
      LMNPCompta::Commands::Journal::Saisir.new(args).execute
    end
    assert_match(/Sens invalide/, err.message)
  end

  def test_interactive_mode_with_libelle_ligne
    inputs = [
      "2025-02-10", # Date
      "AC",         # Journal
      "Achat test", # Libellé
      "",           # Ref
      "606000",     # Compte 1
      "D",          # Sens 1
      "75.50",      # Montant 1
      "Fourniture", # Libelle ligne 1
      "512000",     # Compte 2
      "C",          # Sens 2
      "75.50",      # Montant 2
      "",           # Libelle ligne 2 (empty)
      "o"           # Enregistrer
    ]

    original_stdin = $stdin
    $stdin = StringIO.new(inputs.join("\n") + "\n")

    begin
      capture_io do
        LMNPCompta::Commands::Journal::Saisir.new([]).execute
      end
    ensure
      $stdin = original_stdin
    end

    journal = YAML.load_file(JOURNAL_FILE)
    assert_equal 1, journal.length
    entry = journal.first

    l1 = entry['lignes'].find { |l| l['compte'] == '606000' }
    assert_equal "Fourniture", l1['libelle_ligne']

    l2 = entry['lignes'].find { |l| l['compte'] == '512000' }
    assert_nil l2['libelle_ligne']
  end
end
