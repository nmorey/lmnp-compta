require 'minitest/autorun'
require_relative '../lib/lmnp_compta/fiscal/base'
require_relative '../lib/lmnp_compta/entry'

class FiscalBaseTest < Minitest::Test
  class TestFiscal < LMNPCompta::Fiscal::Base
    # Expose helper for testing
    public :sum_prefix
  end

  def test_filters_entries_by_year
    entries = []
    
    # Entry from 2025
    e1 = LMNPCompta::Entry.new(date: "2025-01-01", journal: "AC", libelle: "2025")
    e1.add_debit("606000", 100)
    e1.add_credit("512000", 100)
    entries << e1

    # Entry from 2024
    e2 = LMNPCompta::Entry.new(date: "2024-12-31", journal: "AC", libelle: "2024")
    e2.add_debit("606000", 200) # Should be ignored
    e2.add_credit("512000", 200)
    entries << e2

    # Analyze for 2025
    analyzer = TestFiscal.new(entries, [], {}, 2025)
    
    # 606000 should sum only 100 (from 2025), ignoring 200 (from 2024)
    assert_equal "100,00", analyzer.sum_prefix("60").to_s
  end
end
