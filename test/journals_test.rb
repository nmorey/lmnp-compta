require 'minitest/autorun'
require 'fileutils'
require 'yaml'
require_relative '../lib/lmnp_compta/journals'
require_relative '../lib/lmnp_compta/journal'
require_relative '../lib/lmnp_compta/entry'
require_relative '../lib/lmnp_compta/montant'

# Test suite for LMNPCompta::Journals class.
class JournalsTest < Minitest::Test
  # Set up a temporary data directory with mock journals for multiple years.
  #
  # @return [void]
  def setup
    @test_dir = File.join(__dir__, 'tmp', 'journals_test_data')
    FileUtils.rm_rf(@test_dir)
    FileUtils.mkdir_p(@test_dir)

    # Use Settings to point to our test directory
    @original_data_dir = LMNPCompta::Settings.instance.data_dir
    LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, @test_dir)

    # Create dummy journal for 2024
    # Entry ID: 1, Ref: REF2024
    # Total debit/credit are balanced so Journal is happy
    entry_2024 = {
      'id' => 1,
      'date' => '2024-06-15',
      'libelle' => 'Test 2024',
      'ref' => 'REF2024',
      'journal' => 'VT',
      'lines' => [
        { 'compte' => '706000', 'credit' => '100.00', 'debit' => '0.00', 'libelle_ligne' => 'Line 1' },
        { 'compte' => '512000', 'credit' => '0.00', 'debit' => '100.00', 'libelle_ligne' => 'Line 2' }
      ]
    }
    FileUtils.mkdir_p(File.join(@test_dir, '2024'))
    File.write(File.join(@test_dir, '2024', 'journal.yaml'), [entry_2024].to_yaml)

    # Create dummy journal for 2025
    # Entry ID: 1 (DUPLICATE ID!), Ref: REF2025
    entry_2025 = {
      'id' => 1,
      'date' => '2025-06-15',
      'libelle' => 'Test 2025',
      'ref' => 'REF2025',
      'journal' => 'VT',
      'lines' => [
        { 'compte' => '706000', 'credit' => '200.00', 'debit' => '0.00', 'libelle_ligne' => 'Line 1' },
        { 'compte' => '512000', 'credit' => '0.00', 'debit' => '200.00', 'libelle_ligne' => 'Line 2' }
      ]
    }
    FileUtils.mkdir_p(File.join(@test_dir, '2025'))
    File.write(File.join(@test_dir, '2025', 'journal.yaml'), [entry_2025].to_yaml)
  end

  # Tear down the temporary data directory and restore original settings.
  #
  # @return [void]
  def teardown
    FileUtils.rm_rf(@test_dir)
    LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, @original_data_dir)
  end

  # Test that initialize loads all journals in the data directory and all returns them.
  #
  # @return [void]
  def test_load_all_journals_and_all
    journals = LMNPCompta::Journals.new(@test_dir)
    assert_equal 2, journals.all.length
    assert_equal [2024, 2025], journals.all.map(&:year).sort
  end

  # Test find_by_year retrieves the correct journal or nil if not present.
  #
  # @return [void]
  def test_find_by_year
    journals = LMNPCompta::Journals.new(@test_dir)

    journal_2024 = journals.find_by_year(2024)
    refute_nil journal_2024
    assert_equal 2024, journal_2024.year

    journal_2026 = journals.find_by_year(2026)
    assert_nil journal_2026
  end

  # Test that entries aggregates all entries across multiple years, even with duplicate IDs.
  #
  # @return [void]
  def test_entries_handles_duplicate_ids
    journals = LMNPCompta::Journals.new(@test_dir)
    all_entries = journals.entries

    assert_equal 2, all_entries.length
    # Both entries have ID 1
    assert_equal [1, 1], all_entries.map(&:id)
    assert_equal ['Test 2024', 'Test 2025'], all_entries.map(&:libelle).sort
  end

  # Test that find_by_year_and_id retrieves the correct entry unambiguously.
  #
  # @return [void]
  def test_find
    journals = LMNPCompta::Journals.new(@test_dir)

    entry_2024 = journals.find(2024, 1)
    refute_nil entry_2024
    assert_equal 'Test 2024', entry_2024.libelle

    entry_2025 = journals.find(2025, 1)
    refute_nil entry_2025
    assert_equal 'Test 2025', entry_2025.libelle

    assert_nil journals.find(2026, 1)
  end

  # Test that check_duplicate_refs does not raise when references are unique.
  #
  # @return [void]
  def test_check_duplicate_refs_no_duplicates
    journals = LMNPCompta::Journals.new(@test_dir)
    # This should not raise an error as REF2024 and REF2025 are unique
    journals.check_duplicate_refs
  end

  # Test that check_duplicate_refs raises when there is a duplicate reference across journals.
  #
  # @return [void]
  def test_check_duplicate_refs_raises_on_duplicates
    # Create duplicate ref in 2025 journal
    entry_2025_dup = {
      'id' => 1,
      'date' => '2025-06-15',
      'libelle' => 'Test 2025 Duplicate Ref',
      'ref' => 'REF2024', # DUPLICATE REF from 2024!
      'journal' => 'VT',
      'lines' => [
        { 'compte' => '706000', 'credit' => '200.00', 'debit' => '0.00', 'libelle_ligne' => 'Line 1' },
        { 'compte' => '512000', 'credit' => '0.00', 'debit' => '200.00', 'libelle_ligne' => 'Line 2' }
      ]
    }
    File.write(File.join(@test_dir, '2025', 'journal.yaml'), [entry_2025_dup].to_yaml)

    journals = LMNPCompta::Journals.new(@test_dir)
    assert_raises(RuntimeError) do
      journals.check_duplicate_refs
    end
  end
end
