# frozen_string_literal: true
# https://nandovieira.com/creating-generators-and-executables-with-thor
require 'thor'
require 'ros/cli/be/main'
require 'ros/cli/lpass'

# TODO: move new, generate and destroy to ros/generators
# NOTE: it should be possible to invoke any operation from any of rake task, cli or console

module Ros
  module Cli
    class Main < Thor
      def self.exit_on_failure?; true end

      check_unknown_options!
      class_option :v, type: :boolean, default: false, desc: 'verbose output'
      class_option :n, type: :boolean, default: false, desc: "run but don't execute action"

      desc 'version', 'Display version'
      def version; say "Ros #{VERSION}" end

      desc 'new NAME', 'Create a new Ros project. "ros new my_project" creates a new project in "./my_project"'
      option :force, type: :boolean, default: false, aliases: '-f'
      def new(name)
        # name = args[0]
        FileUtils.rm_rf(name) if Dir.exists?(name) and options.force
        raise Error, set_color("ERROR: #{name} already exists. Use -f to force", :red) if Dir.exists?(name)
        generate_project(args)
      end

      desc 'console', 'Start the Ros console (short-cut alias: "c")'
      map %w(c) => :console
      def console
        # context(options).switch!
        Pry.start
      end

      desc 'be COMMAND', 'Invoke backend commands'
      subcommand 'be', Ros::Cli::Be::Main

      desc 'lpass COMMAND', "Transfer the contents of #{Ros.env} to/from a Lastpass account"
      option :username, aliases: '-u'
      subcommand 'lpass', Ros::Cli::Lpass

      private

      def generate_project(args)
        name = args[0]
        # host = URI(args[1] || 'http://localhost:3000')
        # args.push(:nil, :nil, :nil)
        require 'ros/generators/project/project_generator.rb'
        generator = Ros::Generators::Project::ProjectGenerator.new(args)
        generator.destination_root = name
        generator.invoke_all
        require 'ros/generators/stack/env/env_generator.rb'
        %w(development test production).each do |env|
          generator = Ros::Generators::EnvGenerator.new([env, nil, name, nil])
          generator.destination_root = name
          generator.invoke_all
        end
        # require 'ros/generators/be/application/platform/rails/rails_generator.rb'
        # generator = Ros::Generators::Be::RailsGenerator.new(args)
        # generator.destination_root = "#{name}/be"
        # generator.invoke_all
      end
    end
  end
end
