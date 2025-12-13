require 'minitest/autorun'
require_relative '../lib/lmnp_compta/entry'
require_relative '../lib/lmnp_compta/montant'

class EntryTest < Minitest::Test
  def setup
    @entry = LMNPCompta::Entry.new(
      id: 1,
      date: "2025-01-01",
      journal: "BQ",
      libelle: "Test Transaction"
    )
  end

  def test_add_lines
    @entry.add_debit("606000", 100)
    @entry.add_credit("512000", 100)

    assert_equal 2, @entry.lines.length
    assert_equal "100.00", @entry.lines[0][:debit].to_s
    assert_equal "100.00", @entry.lines[1][:credit].to_s
  end

  def test_balance
    @entry.add_debit("606000", 100)
    @entry.add_credit("512000", 80)

    # 100 (Debit) - 80 (Credit) = 20
    assert_equal "20.00", @entry.balance.to_s
    refute @entry.balanced?

    @entry.add_credit("512000", 20)
    assert @entry.balanced?
  end

  def test_validation
    # Empty lines
    refute @entry.valid?

    # Unbalanced
    @entry.add_debit("606000", 100)
    refute @entry.valid?

    # Balanced
    @entry.add_credit("512000", 100)
    assert @entry.valid?
  end

  def test_serialization
    @entry.add_debit("606000", 100)
    @entry.add_credit("512000", 100)
    
    hash = @entry.to_h
    assert_equal 1, hash['id']
    assert_equal "2025-01-01", hash['date']
    assert_equal 2, hash['lignes'].length
    # Check string formatting in hash
    assert_equal "100.00", hash['lignes'][0]['debit']
  end
end
