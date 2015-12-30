module RestfulClientLogger
  module_function

  def logger
    @logger ||= (rails_logger || $log || default_logger)
  end

  def rails_logger
    (defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger) ||
      (defined?(RAILS_DEFAULT_LOGGER) && RAILS_DEFAULT_LOGGER.respond_to?(:debug) && RAILS_DEFAULT_LOGGER)
  end

  def default_logger
    require 'logger'
    alogger = Logger.new(STDOUT)
    alogger.level = Logger::INFO
    alogger.datetime_format = '%c'
    alogger
  end

  def logger=(logger)
    @logger = logger
  end
end
