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
        assert_equal "SOSH-01/2025", data[:ref]
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
        assert_instance_of LMNPCompta::InvoiceParser::EdfEcheancier, parser

        entries = parser.parse
        assert_equal 2, entries.length

        assert_equal "50.00", entries[0][:montant].to_s
        assert_equal "Echéance EDF Janvier 2025", entries[0][:libelle]

        assert_equal "50.00", entries[1][:montant].to_s
        assert_equal "Echéance EDF Février 2025", entries[1][:libelle]
        assert_match(/^EDF-F\d{2}\/\d{4}-P01\/2025$/, entries[0][:ref])
    end

    def test_edf_echeancier_with_pdl
        text = <<~TXT
      EDF
      Votre calendrier de paiement
      Date d'édition : 09/09/2026
      • Point de livraison (PDL) :
      N° 19 575 976 773 209
      Le 10/09/2026 65,00 €
      Le 10/10/2026 65,00 €
    TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::EdfEcheancier, parser

        entries = parser.parse
        assert_equal 2, entries.length
        assert_equal "EDF-19575976773209-F09/2026-P09/2026", entries[0][:ref]
        assert_equal "EDF-19575976773209-F09/2026-P10/2026", entries[1][:ref]
    end

    def test_edf_echeancier_with_pdl_layout_format
        text = <<~TXT
      EDF
      Votre calendrier de paiement
      Date d'édition : 09/09/2026
      • Point de livraison (PDL) :                     Montant total TTC        935,00 €
      N° 19 575 976 773 209
      Le 10/09/2026 65,00 €
    TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::EdfEcheancier, parser

        entries = parser.parse
        assert_equal 1, entries.length
        assert_equal "EDF-19575976773209-F09/2026-P09/2026", entries[0][:ref]
    end

    def test_edf_invoice_with_pdl
        text = <<~TXT
      EDF
      Facture du 22/01/2026
      Détail de la facture du 22/01/2026 N° 123456789
      Facture TTC 120,50 €
      • Point de livraison (PDL) :
      N° 19 525 470 252 291
    TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::Edf, parser

        entries = parser.parse
        assert_equal 1, entries.length
        assert_equal "EDF-19525470252291-FAC-20260122-123456789", entries[0][:ref]
        assert_equal "120.50", entries[0][:montant].to_s
        assert_equal Date.new(2026, 1, 22), entries[0][:date]
    end

    def test_edf_invoice_without_pdl
        text = <<~TXT
      EDF
      Facture du 22/01/2026
      Détail de la facture du 22/01/2026 N° 123456789
      Facture TTC 120,50 €
    TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::Edf, parser

        entries = parser.parse
        assert_equal 1, entries.length
        assert_equal "EDF-FAC-20260122-123456789", entries[0][:ref]
    end

    def test_unknown_format
        text = "Ceci n'est pas une facture connue"
        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_nil parser
    end
end
