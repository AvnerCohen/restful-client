require 'yaml'
require 'typhoeus'
require 'service_jynx'
require 'json'
require_relative './restfull_client_configuration.rb'
require_relative './restfull_client_logger.rb'
require_relative './restfull_client_uri.rb'

module RestfullClient
  module_function

  class RestError < StandardError; end

  @@configuration  = nil
  @@logger = nil
  @@timeout_occured_count = 0

  SERVER_SIDE_ERRORS_RANGE = 500

  def self.configure
    @@configuration ||= RestfullClientConfiguration.new
    yield(configuration)
    @@configuration.run!
    @@logger = RestfullClientLogger.logger
  end

  def configuration
    @@configuration
  end

  def logger
    @@logger
  end

  def srv_url(caller)
    callerr_config(caller)["url"]
  end

  def get(caller, path, params = {}, extra_options = {}, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    headers = { "Accept" => "text/json" }
    headers.merge!(extra_options.fetch("headers", {}))
    request = Typhoeus::Request.new(url, headers: headers, method: 'GET', timeout: timeout, params: params)
    run_safe_request(caller, request, true, &on_error_block)
  end

  def post(caller, path, payload, extra_options = {}, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    headers, payload_as_str = prepare_payload_with_headers(payload, extra_options.fetch("headers", {}))
    request = Typhoeus::Request.new(url, headers: headers, method: 'POST', body: payload_as_str, timeout: timeout)
    run_safe_request(caller, request, false, &on_error_block)
  end

  def post_raw(caller, path, payload, custom_timeout = timeout, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    request = Typhoeus::Request.new(url, method: 'POST', body: payload, timeout: custom_timeout)
    run_safe_request(caller, request, false, &on_error_block)
  end

  def delete(caller, path, payload = {}, extra_options = {}, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    headers, payload_as_str = prepare_payload_with_headers(payload, extra_options.fetch("headers", {}))
    request = Typhoeus::Request.new(url, headers: headers, method: 'DELETE', body: payload_as_str, timeout: timeout)
    run_safe_request(caller, request, true, &on_error_block)
  end

  def put(caller, path, payload, extra_options = {}, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    headers, payload_as_str = prepare_payload_with_headers(payload, extra_options.fetch("headers", {}))
    request = Typhoeus::Request.new(url, headers: headers, method: 'PUT', body: payload_as_str, timeout: timeout)
    run_safe_request(caller, request, false, &on_error_block)
  end

  def callerr_config(caller)
    caller_setup = configuration.data["#{caller}#{legacy_postfix}"]
    raise "Couldn't find ['#{caller}#{legacy_postfix}'] in the configuration YAML !!" unless caller_setup
    caller_setup
  end

  def run_safe_request(caller, request, retry_if_needed, &on_error_block)

    @@timeout_occured_count = 0
    if !use_jynx?
      response = run_request(request.dup, __method__, false)
    elsif ServiceJynx.alive?(caller)
      begin
        response = run_request(request.dup, __method__, retry_if_needed)
      end while response.is_a?(Typhoeus::Response)

      response
    else
      response = on_error_block.call("#{caller} set as down.") if on_error_block
    end
    response
  rescue => e
    res = ServiceJynx.failure!(caller) if use_jynx?
    report_method.call("ServiceJynx", "Service #{caller} was taken down as a result of exception", e) if res == :WENT_DOWN
    on_error_block.call("Exception in #{caller} execution - #{e.message}") if on_error_block
  end

  def run_request(request, method, retry_if_needed)
    logger.debug { "#{__method__} :: Request :: #{request.inspect}" }
    request.options[:headers].merge!({'X-Forwarded-For' => $client_ip}) if $client_ip
    request.options[:headers].merge!({'User-Agent' => user_agent})
    request.on_complete do |response|
      #200, OK
      if response.success?
        logger.debug { "Success in #{method} :: Code: #{response.response_code}, #{response.body}" }
        return "" if response.body.empty?
        begin
          return JSON.parse(response.body)
        rescue => e
          logger.error { "Response from #{response.effective_url} is not a valid json  - [#{response.body}]"}
          raise e
        end
        #Timeout occured
      elsif response.timed_out?
        @@timeout_occured_count = @@timeout_occured_count + 1
        skip_raise = (retry_if_needed && @@timeout_occured_count <= retries)

        error_type = "TimeoutOccured"
        error_description = prettify_logger(error_type, request, response)
        logger.error { "Time out in #{method} for: #{error_description}" }

        exception = RuntimeError.new(error_description)
        exception.set_backtrace(caller)
        report_method.call("RestError", error_description, exception)

        raise RestError.new(response.return_code.to_sym) unless skip_raise
        # Could not get an http response, something's wrong.
      elsif response.code == 0

        error_type = :HttpError
        error_description = prettify_logger(error_type, request, response)
        logger.error { "HttpError Error #{response.code}/#{response.return_code} for: #{error_description}" }

        exception = RuntimeError.new(error_description)
        exception.set_backtrace(caller)
        report_method.call("RestError", error_description, exception)
        raise RestError.new(error_type)
        # Received a non-successful http response.
      elsif response.code >= SERVER_SIDE_ERRORS_RANGE

        error_type = :BadReturnCode
        error_description = prettify_logger(error_type, request, response)
        logger.error { "#{error_type} #{response.code}/#{response.return_code} for: #{error_description}" }

        report_method.call("RestError", error_description, exception)
        exception = RuntimeError.new(error_description)

        exception.set_backtrace(caller)

        raise RestError.new(error_type)
      else

        raise RestError.new(:BadReturnCode)

      end
    end
    request.run
  end

  def prepare_payload_with_headers(payload, custom_headers)
    headers = {}
    if payload.is_a?(Hash)
      payload_as_str = payload.to_json(root: false)
      headers.merge!({ "Content-Type" => "application/json" })
    else
      payload_as_str = payload
    end

    headers.merge!(custom_headers)

    [headers, payload_as_str]
  end

  def fake(caller, path, options = {}, &block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    Typhoeus.stub(url, options = {}, &block)
  end

  def timeout
    configuration.timeout
  end

  def user_agent
    configuration.user_agent
  end

  def use_jynx?
    configuration.use_jynx
  end

  def legacy_postfix
    configuration.legacy_postfix
  end

  def retries
    configuration.retries
  end

  def report_method
    configuration.report_method
  end

  def prettify_logger(type, request, response)
    return "#{type} with no request or response." unless request || response
    "#{type} #{response.code}/#{response.return_code} for: #{request.options.fetch(:method)} #{request.base_url}, Total time: #{response.total_time} seconds"
  end

end
