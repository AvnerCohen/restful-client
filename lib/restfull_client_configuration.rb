class RestfullClientConfiguration
  attr_accessor :config_folder, :report_method, :data, :env_name, :timeout
  DEFAULT_TIMEOUT = 10

  def run!
    raise "Configuration directory name must be provided" unless config_folder.class.to_s == "String"
    file_name = File.join(config_folder, "restfull_services.yml")
    @data = YAML.load(ERB.new(File.read(file_name)).result)[env].each do |name, entry|
      next unless entry.has_key?("url")
      opts = {
        time_window_in_seconds: entry.fetch(:time_window_in_seconds, 20),
        max_errors: entry.fetch(:max_errors, 10),
        grace_period: entry.fetch(:grace_period, 120)
      }
      ServiceJynx.register!(name, opts)
    end

    ## set defaults
    unless @report_method
      @report_method = proc {|*args| nil }
    end
    unless @timeout
      @timeout = DEFAULT_TIMEOUT
    end
  end

  def report_on
    @report_method.call("Initialized at: #{Time.now}.")
  end

  def env
    @env_name || "default"
  end

end
