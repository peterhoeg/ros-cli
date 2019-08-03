# frozen_string_literal: true

require 'ros/be/application/cli_base'
require 'ros/be/application/cli/generate'
require 'ros/be/application/cli/rails'
require 'ros/be/infra/generator'
require 'ros/be/application/generator'

module Ros
  module Be
    module Application
      class Cli < Thor
        include CliBase
        def self.exit_on_failure?; true end
        check_unknown_options!
        class_option :v, type: :boolean, default: false, desc: 'verbose output'
        class_option :n, type: :boolean, default: false, desc: "run but don't execute action"

        # desc 'infra', 'Run terraform to create/destroy infrastructure'
        # subcommand 'infra', Ros::Cli::Be::Infra

        desc 'generate TYPE', 'Generate a new asset of type TYPE (short-cut alias: "g")'
        map %w(g) => :generate
        option :force, type: :boolean, default: false, aliases: '-f'
        subcommand 'generate', Ros::Be::Application::GenerateCli

        # TODO: refactor setting action to :destroy
        desc 'destroy TYPE', 'Destroy an asset (environment or service)'
        option :behavior, type: :string, default: 'revoke'
        map %w(d) => :destroy
        subcommand 'destroy', Ros::Be::Application::GenerateCli

        desc 'init', 'Initialize a project environment'
        def init
          preflight_check(fix: true)
          preflight_check
        end

        desc 'status', 'Show platform services status'
        def status
          context(options).status
        end

        desc 'build IMAGE', 'build one or all images'
        map %w(b) => :build
        def build(*services)
          context(options).build(services)
        end

        desc 'test IMAGE', 'test one or all images'
        def test(*services)
          exit context(options).test(services)
        end

        desc 'push IMAGE', 'push one or all images'
        def push(*services)
          context(options).push(services)
        end

        desc 'up SERVICE', 'bring up service(s)'
        option :build, type: :boolean, aliases: '-b', desc: 'Build image before run'
        option :console, type: :boolean, aliases: '-c', desc: 'Connect to service console after starting'
        option :daemon, type: :boolean, aliases: '-d', desc: 'Run in the background'
        option :force, type: :boolean, default: false, aliases: '-f', desc: 'Force cluster creation'
        option :process, type: :boolean, default: true, desc: 'Run or skip the default processs when starts'
        option :profile, type: :string, default: 'server', aliases: '-p', desc: 'Service profile to bring up'
        option :replicas, type: :numeric, aliases: '-r', desc: 'Number of containers (instance) or pods (kubernetes) to run'
        option :seed, type: :boolean, aliases: '--seed', desc: 'Seed the database before starting the service'
        option :shell, type: :boolean, aliases: '--sh', desc: 'Connect to service shell after starting'
        def up(*services)
          context(options).up(services)
        end

        desc 'server PROFILE', 'Start all services (short-cut alias: "s")'
        option :daemon, type: :boolean, aliases: '-d'
        option :environment, type: :string, aliases: '-e', default: 'development'
        map %w(s) => :server
        def server
          # TODO: Test this
          Ros.load_env(options.environment) if options.environment != Ros.default_env
          context(options).up
        end

        desc 'ps', 'List running services'
        def ps
          context(options).ps
        end

        desc 'show', 'show service config'
        def show(service)
          context(options).show(service)
        end

        desc 'credentials', 'show iam credentials'
        def credentials
          context(options).credentials
        end

        desc 'console', 'Start the Ros console (short-cut alias: "c")'
        map %w(c) => :console
        def console(service)
          context(options).console(service)
        end

        desc 'exec SERVICE COMMAND', 'execute an interactive command on a service (short-cut alias: "e")'
        map %w(e) => :exec
        def exec(service, command)
          context(options).exec(service, command)
        end

        # TODO: refactor to a rails specifc set of commands in a dedicated file
        desc 'rails SERVICE COMMAND', 'execute a rails command on a service (short-cut alias: "r")'
        map %w(r) => :rails
        def rails(service, command)
          context(options).exec(service, "rails #{command}")
        end

        desc 'sh SERVICE', 'execute an interactive shell on a service'
        # NOTE: shell is a reserved word
        def sh(service)
          context(options).exec(service, 'bash')
        end

        desc 'logs', 'Tail logs of a running service'
        option :tail, type: :boolean, aliases: '-f'
        def logs(service)
          context(options).logs(service)
        end

        desc 'restart SERVICE', 'Start and stop one or more services'
        option :console, type: :boolean, aliases: '-c', desc: 'Connect to service console after starting'
        option :seed, type: :boolean, aliases: '--seed', desc: 'Seed the database before starting the service'
        option :shell, type: :boolean, aliases: '--sh', desc: 'Connect to service shell after starting'
        def restart(*services)
          context(options).restart(services)
        end

        desc 'stop SERVICE', 'Stop a service'
        def stop(*services)
          context(options).stop(services)
        end

        desc 'down', 'bring down platform'
        def down
          context(options).down
        end

        desc 'list', 'List backend application configuration objects'
        map %w(ls) => :list
        def list(what = nil)
          STDOUT.puts 'Options: infra, services, platform' if what.nil?
          STDOUT.puts "#{Settings.components.be.components.application.components[what].components.keys.join("\n")}" unless what.nil?
        end

        desc 'publish', 'Publish API documentation to Postman'
        def publish
          context(options).publish
        end

        private
        def preflight_check(fix: false)
          options = {}
          ros_repo = Dir.exists?(Ros.ros_root)
          environments = Dir["#{Ros.deployments_dir}/*.yml"].select{ |f| not File.basename(f).index('-') }.map{ |f| File.basename(f).chomp('.yml') }
          if fix
            %x(git clone git@github.com:rails-on-services/ros.git) unless ros_repo
            require 'ros/main/env/generator'
            environments.each do |env|
              Ros::Main::Env::Generator.new([env]).invoke_all if not File.exists?("#{Ros.environments_dir}/#{env}.yml")
            end
          else
            STDOUT.puts "ros repo: #{ros_repo ? 'ok' : 'missing'}"
            env_ok = environments.each do |env|
              break false if not File.exists?("#{Ros.environments_dir}/#{env}.yml")
            end
            STDOUT.puts "environment configuration: #{env_ok ? 'ok' : 'missing'}"
          end
        end

        def context(options = {})
          return @context if @context
          raise Error, set_color("ERROR: Not a Ros project", :red) if Ros.root.nil?
          require "ros/be/application/cli/#{infra_x.cluster_type}"
          @context = Ros::Be::Application.const_get(infra_x.cluster_type.capitalize).new(options)
          @context
        end
        def infra_x; Ros::Be::Infra::Model end
        def application; Ros::Be::Application::Model end
      end
    end
  end
end
