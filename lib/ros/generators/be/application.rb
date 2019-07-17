# frozen_string_literal: true
require 'ros/generators/be/cluster'

module Ros
  module Generators
    module Be
      module Application
        class << self
          def settings; Settings.components.be.components.application end
          def config; settings.config || {} end
          def deploy_path; "tmp/deployments/#{Ros.env}/be/application" end

          def environment
            @environment ||= Stack.environment.dup.merge!(settings.environment.merge!(calculated_envs.to_h).to_h)
          end

          # Common environment for application services
          def calculated_envs
            Config::Options.new({
              infra: {
                provider: Settings.components.be.config.provider,
                bucket_name: Application.bucket_name
              },
              platform: {
                feature_set: Stack.current_feature_set,
              },
              bucket_name: Application.bucket_name
            }) # .merge!(send("#{Settings.components.be.config.provider}_environment"))
          end

          def api_hostname
            @api_hostname ||= "#{config.endpoints.api.host}#{base_hostname}"
          end

          def sftp_hostname
            @sftp_hostname ||= "#{config.endpoints.sftp.host}#{base_hostname}"
          end

          def base_hostname
            @base_hostname ||= (config.dns ? "#{Stack.override_feature_set ? '-' + Stack.current_feature_set : ''}.#{dns_domain}" : 'localhost')
          end

          def dns_domain
            @dns_domain ||= "#{config.dns.subdomain}.#{config.dns.domain}"
          end

          def bucket_name
            @bucket_name ||= "#{Stack.current_feature_set}-#{Stack.name}-#{Cluster.name}"
          end
        end
      end
    end
  end
end
