module LMNPCompta
    # Représente un bien immobilier amortissable
    class Stock
        attr_accessor :ard, :deficit, :file_path


        def self.load(file)
                x = (File.exist?(file) ? YAML.load_file(file) : {})
                x[:file_path] = file
                Stock.new(x)
        end

        # Initialise un nouveau bien
        # @param attrs [Hash] Attributs du bien
        def initialize(attrs = {})
            @file_path = nil
            @ard = Montant.new(attrs['ard'] || attrs[:ard] || 0)
            @deficit = Montant.new(attrs['deficit'] || attrs[:deficit] || 0)
            @file_path = attrs['file_path'] || attrs[:file_path]
        end

        # Sauvegarde les entrées dans le fichier YAML
        def save!(file=@file_path)
            raise "Cannot save Stock file. No path set" if file == nil
            FileUtils.mkdir_p(File.dirname(file))
            File.write(file, self.to_h.to_yaml)
        end

        # Convertit l'objet en Hash pour la sérialisation
        # @return [Hash]
        def to_h
            {
                'ard' => @ard.to_s,
                'deficit' => @deficit.to_s,
            }
        end
    end
end
