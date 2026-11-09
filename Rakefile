require 'yard'
require 'bundler/setup'
require 'rake/testtask'

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
  t.options = ['--title', 'LMNP-Compta Documentation', '--protected', '--private']
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.ruby_opts << '-rtest_helper'
  t.pattern = "test/*_test.rb"
  t.verbose = true
end

task :check_whitespace do
  puts "Checking for trailing whitespace..."
  files = Dir.glob('lib/**/*.rb') + Dir.glob('bin/*') + ['Rakefile']
  errors = []
  files.each do |file|
    next if File.directory?(file)
    lines = File.readlines(file)
    lines.each_with_index do |line, index|
      if line =~ /[ \t]+$/
        errors << "#{file}:#{index + 1}: trailing whitespace found"
      end
    end
  end

  if errors.any?
    puts errors.join("\n")
    exit 1
  else
    puts "No trailing whitespace found."
  end
end

task default: [:check_whitespace, :test, :yard]
