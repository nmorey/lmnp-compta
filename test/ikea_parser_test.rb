require 'minitest/autorun'
require_relative '../lib/lmnp_compta/invoice_parser'
require_relative '../lib/lmnp_compta/invoice_parsers/ikea'

class IkeaParserTest < Minitest::Test
    def test_ikea_parser
        text = <<~TXT
            IKEA
            Facture
            Vendeur:
            Meubles IKEA France SAS
            425 Rue Henri Barbusse
            78375 Plaisir
            France
            Numéro de TVA: FR83351745724
            Détail facture:
            Date de commande: 30/12/2025
            Numéro de commande: 1571902358
            Date de facture: 30/12/2025
            Numéro de facture: FRINV26000001449702
            Date de livraison prévue: 06.01.2026

            Total montant HT: 49,48 €
            Total montant TVA: 9,92 €
            Montant de la facture: 59,40 €
        TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::Ikea, parser

        data = parser.parse.first
        assert_equal Date.new(2025, 12, 30), data[:date]
        assert_equal "FRINV26000001449702", data[:ref]
        assert_equal "59.40", data[:montant].to_s
        assert_equal "Achat Ikea FRINV26000001449702", data[:libelle]
        assert_equal "606300", data[:compte_charge]
    end
end
