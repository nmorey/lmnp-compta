Gem::Specification.new do |spec|
  spec.name          = "lmnp_compta"
  
  # Calculate version from git tags
  # Fallback to 0.1.0 if no git or no tags
  git_version = `git describe --tags 2>/dev/null`.chomp
  clean_version = if git_version.empty?
                    "0.1.0"
                  else
                    git_version.gsub(/^v/, "").gsub(/-([0-9]+)-g/, '-\1.g')
                  end

  spec.version       = clean_version
  spec.authors       = ["Nicolas Morey"]
  spec.email         = ["nicolas@morey-chaisemartin.com"]

  spec.summary       = "Outil CLI pour la comptabilité LMNP (Loueur Meublé Non Professionnel)"
  spec.description   = "Gérez votre comptabilité LMNP au régime réel simplifié : import Airbnb, OCR factures, amortissements, liasse fiscale et export FEC."
  spec.homepage      = "https://github.com/nmorey/lmnp-compta"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md LICENSE lmnp-completion.bash]
  
  spec.bindir        = "bin"
  spec.executables   = ["lmnp"]
  spec.require_paths = ["lib"]

  # Standard library dependencies (explicitly required for Ruby 3.4+ where they are default gems)
  spec.add_dependency "csv"
  spec.add_dependency "bigdecimal"
  spec.add_dependency "delegate"
  # yaml, date, optparse, readline, open3 are default gems or stdlib

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end