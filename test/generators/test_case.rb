require "test_helper"

module Skadi
  module Generators
    class TestCase < Rails::Generators::TestCase
      destination File.expand_path("../../tmp", __dir__)
      setup :prepare_destination

      cattr_accessor :generator_file_name
      def self.generates(file_name)
        self.generator_file_name = file_name
      end

      private def generate_migration(*args)
        run_generator(args)

        relative_file_path = "db/migrate/#{generator_file_name}.rb"
        file_name = migration_file_name(relative_file_path)
        assert file_name, "Could not find migration #{relative_file_path}"

        content = File.read(file_name)

        assert valid_ruby_syntax?(content), "Expected migration #{file_name} to be valid Ruby"

        content
      end

      def valid_ruby_syntax?(code_string)
        RubyVM::InstructionSequence.compile(code_string)
        true
      rescue SyntaxError => e
        puts "Syntax error: #{e.message}"
        false
      end
    end
  end
end
