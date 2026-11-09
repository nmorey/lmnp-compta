require_relative '../montant'

module LMNPCompta
  module Fiscal
    # Module facilitant la construction de rapports et documents de synthèse fiscale.
    module Reporting
      # Composant de base abstrait pour les éléments de rapport.
      class Component
        # Convertit le composant en chaîne formatée.
        # @return [String] représentation textuelle
        def to_s
          raise NotImplementedError
        end
      end

      # Représente une case de formulaire fiscal (code, libellé, montant).
      class Box < Component
        # @return [String, Symbol] code de la case fiscale (ex: :2033_A_010)
        attr_reader :code
        # @return [String] libellé descriptif
        attr_reader :label
        # @return [LMNPCompta::RoundedMontant] valeur arrondie
        attr_reader :value

        # Initialise une case fiscale.
        # @param code [String, Symbol] code de la case fiscale
        # @param label [String] libellé descriptif
        # @param value [LMNPCompta::RoundedMontant] montant arrondi
        # @param show_zero [Boolean] afficher la case même si la valeur est nulle
        # @raise [ArgumentError] si `value` n'est pas un RoundedMontant
        def initialize(code, label, value, show_zero: false)
          unless value.is_a?(LMNPCompta::RoundedMontant)
            raise ArgumentError, "Box value must be a RoundedMontant, got #{value.class}"
          end
          @code = code
          @label = label
          @value = value
          @show_zero = show_zero
        end

        # Génère la représentation textuelle de la case fiscale.
        # @return [String] ligne formatée
        def to_s
          return "" if !@show_zero && @value.respond_to?(:zero?) && @value.zero?
          # Format: CODE | LABEL : VALUE €
          " #{@code.to_s.ljust(4)} | #{@label.ljust(45)} : #{@value.to_s.rjust(10)} €"
        end
      end

      # Ligne d'information ou de détail complémentaire dans un formulaire fiscal.
      class InfoLine < Component
        # Initialise une ligne d'information.
        # @param label [String] libellé d'information
        # @param value [LMNPCompta::RoundedMontant] valeur arrondie
        # @param comment [String, nil] commentaire facultatif
        # @raise [ArgumentError] si `value` n'est pas un RoundedMontant
        def initialize(label, value, comment = nil)
          unless value.is_a?(LMNPCompta::RoundedMontant)
            raise ArgumentError, "InfoLine value must be a RoundedMontant, got #{value.class}"
          end
          @label = label
          @value = value
          @comment = comment
        end

        # Génère la ligne d'information formatée.
        # @return [String] ligne formatée
        def to_s
          # Format similar to: "   Stock ARD début exercice ........ : 100.00 €"
          str = "   #{@label.ljust(33, '.')} : #{@value.to_s.rjust(10)} €"
          str += " #{@comment}" if @comment
          str
        end
      end

      # Ligne de texte libre au sein d'une section fiscale.
      class Text < Component
        # Initialise un élément de texte.
        # @param text [String] contenu textuel
        def initialize(text)
          @text = text
        end

        # Génère la représentation textuelle indentée.
        # @return [String] texte indenté
        def to_s
          "       #{@text}"
        end
      end

      # Section regroupant plusieurs éléments au sein d'un formulaire fiscal.
      class Section
        # @return [String, nil] titre de la section
        attr_reader :title
        # @return [Array<Component>] liste des éléments contenus
        attr_reader :items

        # Initialise une section fiscale.
        # @param title [String, nil] titre optionnel
        def initialize(title = nil)
          @title = title
          @items = []
        end

        # Ajoute un composant à la section.
        # @param item [Component] élément à ajouter
        # @return [Array<Component>]
        def add(item)
          @items << item
        end

        # Ajoute une case fiscale à la section.
        # @param code [String, Symbol] code de la case
        # @param label [String] libellé de la case
        # @param value [LMNPCompta::RoundedMontant] valeur arrondie
        # @param show_zero [Boolean] afficher si zéro
        # @return [Array<Component>]
        def add_box(code, label, value, show_zero: false)
          add(Box.new(code, label, value, show_zero: show_zero))
        end

        # Ajoute une ligne d'information à la section.
        # @param label [String] libellé
        # @param value [LMNPCompta::RoundedMontant] montant
        # @param comment [String, nil] commentaire
        # @return [Array<Component>]
        def add_info(label, value, comment = nil)
          add(InfoLine.new(label, value, comment))
        end

        # Ajoute un texte à la section.
        # @param text [String] contenu
        # @return [Array<Component>]
        def add_text(text)
          add(Text.new(text))
        end

        # Génère la représentation textuelle complète de la section.
        # @return [String] section formatée
        def to_s
          lines = []
          if @title
            lines << "" if @items.any?
            lines << "#{@title} :"
          end
          lines += @items.map(&:to_s).reject(&:empty?)
          lines.join("\n")
        end
      end

      # Formulaire fiscal contenant plusieurs sections (ex: Cerfa 2033-A).
      class Form < Component
        # @return [String] titre du formulaire
        attr_reader :title
        # @return [Array<Section>] liste des sections
        attr_reader :sections

        # Initialise un formulaire.
        # @param title [String] titre du formulaire
        def initialize(title)
          @title = title
          @sections = []
        end

        # Ajoute une section au formulaire.
        # @param section [Section] section à ajouter
        # @return [Array<Section>]
        def add_section(section)
          @sections << section
        end

        # Génère la représentation textuelle du formulaire.
        # @return [String] formulaire formaté
        def to_s
          out = "\n\n📝 #{@title}\n"
          out += "-" * 59 + "\n"
          out += @sections.map(&:to_s).join("")
          out
        end
      end

      # Document fiscal complet regroupant l'ensemble des formulaires.
      class Document < Component
        # @return [String] titre du document
        attr_reader :title
        # @return [Array<Form>] liste des formulaires
        attr_reader :forms

        # Initialise un document fiscal.
        # @param title [String] titre du document
        def initialize(title)
          @title = title
          @forms = []
        end

        # Ajoute un formulaire au document.
        # @param form [Form] formulaire à ajouter
        # @return [Array<Form>]
        def add_form(form)
          @forms << form
        end

        # Génère la représentation textuelle complète du document.
        # @return [String] document formaté
        def to_s
          out = "\n" + "=" * 59 + "\n"
          out += "       #{@title}\n"
          out += "=" * 59
          out += @forms.map(&:to_s).join("")
          out += "\n" + "=" * 59 + "\n" # Footer line
          out
        end
      end
    end
  end
end
