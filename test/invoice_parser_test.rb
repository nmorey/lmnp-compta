require 'minitest/autorun'
require_relative '../lib/lmnp_compta/invoice_parser'

class InvoiceParserTest < Minitest::Test
    def test_sosh_parser
        text = <<~TXT
      Sosh
      N° de facture : 123456789
      date de facture : 15/01/2025
      total du montant prélevé 25,99 €
    TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::Sosh, parser

        data = parser.parse.first
        assert_equal Date.new(2025, 1, 15), data[:date]
        assert_equal "123456789", data[:ref]
        assert_equal "25.99", data[:montant].to_s
        assert_equal "Internet Sosh Janvier 2025", data[:libelle]
    end

    def test_edf_parser_multiple_lines
        text = <<~TXT
      EDF
      Votre calendrier de paiement
      Le 10/01/2025 50,00 €
      Le 10/02/2025 50,00 €
    TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::Edf, parser

        entries = parser.parse
        assert_equal 2, entries.length

        assert_equal "50.00", entries[0][:montant].to_s
        assert_equal "Echéance EDF Janvier 2025", entries[0][:libelle]

        assert_equal "50.00", entries[1][:montant].to_s
        assert_equal "Echéance EDF Février 2025", entries[1][:libelle]
    end

    def test_unknown_format
        text = "Ceci n'est pas une facture connue"
        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_nil parser
    end
end
