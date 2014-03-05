class RestfullClientConfiguration
  attr_accessor :file_name, :report_method, :data

  def run!
    raise "Configuration File Name must be provided" unless file_name.class.to_s == "String"
    @data = YAML.load(ERB.new(File.read(file_name)).result)[env].each do |name, entry|
      next unless entry.has_key?("url")
      opts = {
        time_window_in_seconds: entry.fetch(:time_window_in_seconds, 20),
        max_errors: entry.fetch(:max_errors, 10),
        grace_period: entry.fetch(:grace_period, 120)
      }
      ServiceJynx.register!(name, opts)
    end
    unless @report_method
      @report_method = proc {|*args| nil }
    end
  end

  def report_on
    @report_method.call("Initialized at: #{Time.now}.")
  end

  def env
    (defined?(Rails) && Rails.env) || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "default"
  end

end
