module LMNPCompta
  module Fiscal
    module Reporting
      class Component
        def to_s
          raise NotImplementedError
        end
      end

      class Box < Component
        attr_reader :code, :label, :value

        def initialize(code, label, value)
          @code = code
          @label = label
          @value = value
        end

        def to_s
          return "" if @value.respond_to?(:zero?) && @value.zero?
          # Format: CODE | LABEL : VALUE €
          " #{@code.to_s.ljust(4)} | #{@label.ljust(45)} : #{@value.to_s.rjust(10)} €"
        end
      end

      class InfoLine < Component
        def initialize(label, value, comment = nil)
          @label = label
          @value = value
          @comment = comment
        end

        def to_s
          # Format similar to: "   Stock ARD début exercice ........ : 100.00 €"
          str = "   #{@label.ljust(33, '.')} : #{@value.to_s.rjust(10)} €"
          str += " #{@comment}" if @comment
          str
        end
      end

      class Text < Component
        def initialize(text)
          @text = text
        end

        def to_s
          "       #{@text}"
        end
      end

      class Section
        attr_reader :title, :items

        def initialize(title = nil)
          @title = title
          @items = []
        end

        def add(item)
          @items << item
        end

        def add_box(code, label, value)
          add(Box.new(code, label, value))
        end

        def add_info(label, value, comment = nil)
          add(InfoLine.new(label, value, comment))
        end

        def add_text(text)
          add(Text.new(text))
        end

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

      class Form < Component
        attr_reader :title, :sections

        def initialize(title)
          @title = title
          @sections = []
        end

        def add_section(section)
          @sections << section
        end

        def to_s
          out = "\n\n📝 #{@title}\n"
          out += "-" * 59 + "\n"
          out += @sections.map(&:to_s).join("")
          out
        end
      end

      class Document < Component
        attr_reader :title, :forms

        def initialize(title)
          @title = title
          @forms = []
        end

        def add_form(form)
          @forms << form
        end

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
