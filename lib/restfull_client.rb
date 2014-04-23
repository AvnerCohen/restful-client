require 'yaml'
require 'typhoeus'
require 'service_jynx'
require 'json'
require 'restfull_client_configuration'
require 'restfull_client_logger'
require 'restfull_client_uri'

module RestfullClient
  extend self

  class RestError < StandardError; end

  attr_accessor :configuration, :logger, :env
  @@timeout_occured_count = 0

  def self.configure
    self.configuration ||= RestfullClientConfiguration.new
    yield(configuration)
    self.configuration.run!
    self.logger = RestfullClientLogger.logger
  end


  def get(caller, path, params = {}, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    request = Typhoeus::Request.new(url, headers: { "Accept" => "text/json" }, method: 'GET', timeout: timeout, params: params)
    run_safe_request(caller, request, true, &on_error_block)
  end

  def post(caller, path, payload, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    headers = {}
    if payload.is_a?(String)
      payload_as_str = payload
    else
      payload_as_str = payload.to_json(root: false)
      headers.merge!({ "Content-Type" => "application/json" })
    end
    request = Typhoeus::Request.new(url, headers: headers, method: 'POST', body: payload_as_str, timeout: timeout)
    run_safe_request(caller, request, false, &on_error_block)
  end

  def delete(caller, path, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    request = Typhoeus::Request.new(url, method: 'DELETE', timeout: timeout)
    run_safe_request(caller, request, true, &on_error_block)
  end

  def put(caller, path, payload, &on_error_block)
    url = RestfullClientUri.uri_join(callerr_config(caller)["url"], path)
    headers = {}
    if payload.is_a?(String)
      payload_as_str = payload
    else
      payload_as_str = payload.to_json(root: false)
      headers.merge!({ "Content-Type" => "application/json" })
    end
    request = Typhoeus::Request.new(url, headers: headers, method: 'PUT', body: payload_as_str, timeout: timeout)
    run_safe_request(caller, request, false, &on_error_block)
  end

  def callerr_config(caller)
    caller_setup = configuration.data[caller]
    raise "Couldn't find >>#{caller}<< in the configuration YAML !!" unless caller_setup
    caller_setup
  end

  def run_safe_request(caller, request, retry_if_needed, &on_error_block)
    @@timeout_occured_count = 0

    if ServiceJynx.alive?(caller)
      begin
        response = run_request(request.dup, __method__, retry_if_needed)
      end while response.is_a?(Typhoeus::Response)

      response
    else
      response = on_error_block.call("#{caller}_service set as down.") if on_error_block
    end
    response
  rescue => e
    res = ServiceJynx.failure!(caller)
    report_method.call("ServiceJynx", "Service #{caller} was taken down as a result of exception", e.message) if res == :WENT_DOWN
    on_error_block.call("Exception in #{caller}_service execution - #{e.message}") if on_error_block
  end

  def run_request(request, method, retry_if_needed)
    @logger.debug { "#{__method__} :: Request :: #{request.inspect}" }
    request.options[:headers].merge!({'X-Forwarded-For' => $client_ip}) if $client_ip
    request.on_complete do |response|
      #200, OK
      if response.success?
        @logger.debug { "Success in #{method} :: Code: #{response.response_code}, #{response.body}" }
        return "" if response.body.empty?
        return JSON.parse(response.body)
        #Timeout occured
      elsif response.timed_out?
        @@timeout_occured_count = @@timeout_occured_count + 1
        skip_raise = (retry_if_needed && @@timeout_occured_count <= retries)
        @logger.error { "Got a time out in #{method} for #{request.inspect}" }
        report_method.call("RestError", "Request :: #{request.inspect} in #{method}", "timeout")
        raise RestError.new(:TimeoutOccured) unless skip_raise
        # Could not get an http response, something's wrong.
      elsif response.code == 0
        @logger.error { "Could not get an http response : #{response.return_message} in #{method} for #{request.inspect}" }
        report_method.call("RestError", "Request :: #{request.inspect} in #{method}", "Failed to get response :: #{response.return_message}")
        raise RestError.new(:HttpError)
        # Received a non-successful http response.
      else
        @logger.error { "HTTP request failed in #{method}: #{response.code} for request #{request.inspect}" }
        report_method.call("RestError", "Request :: #{request.inspect} in #{method}", "#{response.code}")
        raise RestError.new(:BadReturnCode)
      end
    end
    request.run
  end

  def timeout
    configuration.timeout
  end

  def retries
    configuration.retries
  end

  def report_method
    configuration.report_method
  end

end
