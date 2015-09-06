require 'erb'

class RestfulClientConfiguration
  attr_accessor :config_folder, :report_method, :data, :env_name, :timeout, :user_agent, :retries, :use_jynx, :legacy_postfix
  DEFAULT_TIMEOUT = 10
  DEFAULT_RETRIES = 2
  DEFAULT_USER_AGENT = 'RestfulClient - https://github.com/AvnerCohen/restful-client'

  def run!
    raise "Configuration directory name must be provided" unless config_folder.class.to_s == "String"
    file_name = ["restful_services.yml", "rest_api.yml"].each do |name|
      locale_name = File.join(config_folder, name)
      break locale_name if File.file?(locale_name)
    end

    ## Set Default Values
    @report_method  ||=     proc {|*args| nil }
    @timeout        ||=     DEFAULT_TIMEOUT
    @user_agent     ||=     DEFAULT_USER_AGENT
    @retries        ||=     DEFAULT_RETRIES
    @legacy_postfix ||=     ""
    @use_jynx         =     true if @use_jynx.nil?

    @data = YAML.load(ERB.new(File.read(file_name)).result)[env].each do |name, entry|
      next unless entry.has_key?("url")
      opts = {
        time_window_in_seconds: entry.fetch(:time_window_in_seconds, 20),
        max_errors: entry.fetch(:max_errors, 10),
        grace_period: entry.fetch(:grace_period, 120)
      }

      ServiceJynx.register!(name.gsub(@legacy_postfix, ""), opts) if @use_jynx
    end

  end

  def reset
    @report_method  =    nil
    @timeout        =    nil
    @user_agent     =    nil
    @retries        =    nil
    @use_jynx       =    nil
    @legacy_postfix =    nil
  end

  ## Dummy method to test reporting phase
  def report_on
    @report_method.call("RestfulClientConfiguration", "Initialized at: #{Time.now}.")
  end

  def env
    @env_name || "default"
  end

end
