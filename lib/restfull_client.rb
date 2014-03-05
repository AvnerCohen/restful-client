require 'uri'
require 'yaml'
require 'typhoeus'
require 'service_jynx'
require 'restfull_client_configuration'
require 'restfull_client_logger'

module RestfullClient
  extend self

  class RestError < StandardError; end

  attr_accessor :configuration, :logger, :report_method, :env

  def self.configure
    self.configuration ||= RestfullClientConfiguration.new
    yield(configuration)
    self.configuration.run!
    self.logger = RestfullClientLogger.logger
  end


  def get(caller, path, params = {}, &on_error_block)
    url = URI::join(callerr_config(caller)["url"], path).to_s
    request = Typhoeus::Request.new(url, headers: { "Accept" => "text/json" }, method: 'GET', timeout: 3, params: params)
    run_safe_request(caller, request, &on_error_block)
  end

  def post(caller, path, payload, &on_error_block)
    url = URI::join(callerr_config(caller)["url"], path).to_s
    request = Typhoeus::Request.new(url, method: 'POST', body: payload, timeout: 300)
    run_safe_request(caller, request, &on_error_block)
  end

  def delete(caller, path, &on_error_block)
    url = URI::join(callerr_config(caller)["url"], path).to_s
    request = Typhoeus::Request.new(url, method: 'DELETE', timeout: 300)
    run_safe_request(caller, request, &on_error_block)
  end

  def put(caller, path, payload, &on_error_block)
    url = URI::join(callerr_config(caller)["url"], path).to_s
    request = Typhoeus::Request.new(url, headers: { "Content-Type" => "application/json" }, method: 'PUT', body: payload.to_json(root: false), timeout: 3)
    run_safe_request(caller, request, &on_error_block)
  end

  def callerr_config(caller)
    configuration.data[caller]
  end

  def run_request(request, method, raise_on_error = false)
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
        @logger.error { "Got a time out in #{method} for #{request.inspect}" }
        @report_method.call("RestError", "Request :: #{request.inspect} in #{method}", "timeout")
        reply_with(:TimeoutOccured, raise_on_error)

        # Could not get an http response, something's wrong.
      elsif response.code == 0
        @logger.error { "Could not get an http response : #{response.return_message} in #{method} for #{request.inspect}" }
        @report_method.call("RestError", "Request :: #{request.inspect} in #{method}", "Failed to get response :: #{response.return_message}")
        reply_with(:HttpError, raise_on_error)

        # Received a non-successful http response.
      else
        @logger.error { "HTTP request failed in #{method}: #{response.code} for request #{request.inspect}" }
        @report_method.call("RestError", "Request :: #{request.inspect} in #{method}", "#{response.code}")
        reply_with(:BadReturnCode, raise_on_error)
      end
    end
    request.run
  end


  private

  def run_safe_request(caller, request, &on_error_block)
    if ServiceJynx.alive?(caller)
      run_request(request, __method__, true)
    else
      on_error_block.call("#{caller}_service set as down.") if on_error_block
    end
  rescue => e
    res = ServiceJynx.failure!(caller)
    @report_method.call("ServiceJynx", "Service #{caller} was taken down as a result of exception", e.message) if res == :WENT_DOWN
    on_error_block.call("Exception in #{caller}_service execution - #{e.message}") if on_error_block
  end

  def reply_with(symbol, raise_on_error)
    if raise_on_error
      raise RestError.new(symbol)
    else
      return symbol
    end
  end

end
