require 'spec_helper'

require 'pry'

def set_global(class_name)
  $some_global = class_name
end

describe :RestfulClient do
  before(:all) do
    # Start a local rack server to serve up test pages.
    Thread.new do
      Rack::Handler::Thin.run MyApp::Test::Server.new, Port: 8383
    end
    # wait a sec for the server to be booted
    sleep 2
  end

  before(:each) do
    $some_global = nil
    Typhoeus::Expectation.clear
    RestfulClient.configuration.reset if RestfulClient.configuration
  end

  describe 'Configuration' do
    it 'raise when file_name not sent in' do
      expect { RestfulClient.configure {} }.to raise_error(RuntimeError)
    end

    it 'correctly read configuration files' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.configuration.data).to_not eq(nil)
    end

    it 'allow accesing url configuration' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.configuration.data['posts']['url']).to eq('http://1.2.3.4:8383/api/v1/')
    end

    it 'allow accesing url configuration by environment' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.configuration.data['posts']['url']).to eq('http://1.2.3.4:8383/api/v0/')
    end

    it 'allow should access with legacy configuration as well' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
        config.legacy_postfix = '_service'
      end

      expect(RestfulClient.callerr_config('pompa')['url']).to_not eq(nil)
    end

    it 'should register jynx with correct name in case of legacy' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
        config.legacy_postfix = '_service'
      end

      expect(ServiceJynx.alive?('pompa')).to eq(true)
    end

    it 'have a logger' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.logger).to respond_to :info
    end

    it 'correctly read the configuration from the registry' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.callerr_config('posts')['url']).to eq('http://1.2.3.4:8383/api/v0/')
    end

    it 'have a timeout defined for the service by default' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.timeout).to eq(10)
    end

    it 'have a timeout defined for the service by default' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
        config.timeout = 2
      end

      expect(RestfulClient.timeout).to eq(2)
    end

    it 'have a user agent defined for the service by default' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.user_agent).to eq(RestfulClientConfiguration::DEFAULT_USER_AGENT)
    end

    it 'have a user agent defined for the service' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
        config.user_agent = 'users_service'
      end

      expect(RestfulClient.user_agent).to eq('users_service')
    end

    it 'have a retries defined for the service by default' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.retries).to eq(2)
    end

    it 'have a retries defined for the service by default' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
        config.retries = 15
      end

      expect(RestfulClient.retries).to eq(15)
    end
  end

  describe 'toJson' do
    it 'automatically run to_json on an object' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      some_object = { 'moshe' => 'test' }
      res = RestfulClient.post('locally', '/bounce', some_object) { |m| m }

      expect(res).to eq(some_object)
    end

    it "doesn't re-run json on data that was already a json object" do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      some_object = { 'moshe' => 'test' }.to_json
      res = RestfulClient.post('locally', '/bounce', some_object) { |m| m }

      expect(res).to eq(JSON.parse(some_object))
    end
  end

  describe 'Restful Client Calls' do
    it 'allow sending in a reporting method (such as graylog/ airbrake instrumentiation)' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
        config.report_method = proc do |*args|
          klass = args.first
          set_global(klass)
        end
      end
      RestfulClient.configuration.report_on

      expect($some_global).to eq('RestfulClientConfiguration')
    end

    it 'report on a server error (end-2-end ish test)' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
        config.timeout = 1
        config.report_method = proc do |*args|
          klass = args.first
          set_global(klass)
        end
      end
      RestfulClient.get('posts', '/a/a/a/a') { nil }

      expect($some_global).to eq('RestError')
    end

    it 'do not report on a client side error (http_code < 500)' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end
      RestfulClient.get('locally', '/client_error') { nil }

      expect($some_global).to be_nil
    end

    it 'do not report on a missing resource (http_code == 404)' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      RestfulClient.get('locally', '/non_existing') { nil }

      expect($some_global).to be_nil
    end

    describe :JynxSetDownScenarios do
      it 'do not fail jynx on a missing (http_code == 404), when failures are over max (10)' do
        RestfulClient.configure do |config|
          config.env_name = 'production'
          config.config_folder = 'spec/config'
        end

        0.upto(9) do
          RestfulClient.get('locally', '/non_existing') { 'default' }
        end

        RestfulClient.get('locally', '/non_existing') { 'default' }

        expect($some_global).to_not eq('ServiceJynx')
      end

      it 'should fail jynx on a bad return code (http_code => 500), when failures are over max (10)' do
        RestfulClient.configure do |config|
          config.env_name = 'production'
          config.config_folder = 'spec/config'
          config.report_method = proc do |*args|
            klass = args.first
            set_global(klass)
          end
        end
        0.upto(9) do
          RestfulClient.get('locally', '/server_error') { 'default' }
        end

        RestfulClient.get('locally', '/server_error') { 'default' }

        expect($some_global).to eq('ServiceJynx')
      end

      it 'should not call server after max errors with http_code => 500' do
        RestfulClient.configure do |config|
          config.env_name = 'production'
          config.config_folder = 'spec/config'
          config.report_method = proc do |*args|
            klass = args.first
            set_global(klass)
          end
        end
        0.upto(10) do
          RestfulClient.get('locally', '/server_error') { 'default' }
        end

        RestfulClient.get('locally', '/server_error') { |msg| $some_global = msg }

        expect($some_global).to include('set as down')
      end

    end
  end

  describe 'Retry call count' do
    it 'repeat the call if retry is set ' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
        config.retries = 3
        config.timeout = 2
        config.report_method = proc do |*args|
          klass = args.first
          set_global(klass)
        end
      end

      # flow is a little wierdish
      # #Run something that hard codedly, in the test_server, increments the counter
      RestfulClient.get('locally', 'a/a/a/b') { |_m| nil }
      # Now checksomething that returns "200", put also the global server counter
      # And asset the number of retries.
      res = RestfulClient.get('locally', 'a') { 'good' }

      expect(res['counter']).to eq(4)
    end
  end

  describe 'Default Value if no block is given' do
    it 'should return nil when no value is given' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
        config.timeout = 1
      end
      res = RestfulClient.get('posts', '/a')
      expect(res).to eq(nil)
    end

    it 'should allow skiping jynx completly' do
      RestfulClient.configure do |config|
        config.config_folder = 'spec/config'
        config.use_jynx = false
        config.timeout = 1
      end
      res = RestfulClient.get('posts', '/a')
      expect(res).to eq(nil)
    end
  end

  describe 'Uri Joining' do
    it 'correct join two paths leading slash defined as [WithSlash : NoSlash]' do
      path = RestfulClientUri.uri_join('http://load-balancer-int01:9999/api/v1/', 'proposals/sent/count/123')
      expect(path).to eq('http://load-balancer-int01:9999/api/v1/proposals/sent/count/123')
    end

    it 'correct join two paths leading slash defined as [WithSlash : WithSlash]' do
      path = RestfulClientUri.uri_join('http://load-balancer-int01:9999/api/v1/', '/proposals/sent/count/123')
      expect(path).to eq('http://load-balancer-int01:9999/api/v1/proposals/sent/count/123')
    end

    it 'correct join two paths leading slash defined as [NoSlash : WithSlash]' do
      path = RestfulClientUri.uri_join('http://load-balancer-int01:9999/api/v1', '/proposals/sent/count/123')
      expect(path).to eq('http://load-balancer-int01:9999/api/v1/proposals/sent/count/123')
    end

    it 'correct join two paths leading slash defined as [NoSlash : NowSlash]' do
      path = RestfulClientUri.uri_join('http://load-balancer-int01:9999/api/v1', 'proposals/sent/count/123')
      expect(path).to eq('http://load-balancer-int01:9999/api/v1/proposals/sent/count/123')
    end
  end

  describe 'Fake response' do
    it 'should return fake response' do
      RestfulClient.configure { |config| config.config_folder = 'spec/config' }

      RestfulClient.fake('locally', 'fake/me') do
        Typhoeus::Response.new(
          code: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: { 'fake' => true }.to_json)
      end

      res = RestfulClient.get('locally', 'fake/me') { nil }
      expect(res).to eq('fake' => true)
    end
  end

  describe 'extra args' do
    it 'should allow sending extra arguments as art of the typehouse request if assigned' do
      expect(Typhoeus::Request).to receive(:new).with(anything,
                                                      headers: { 'Accept' => 'application/json' },
                                                      method: 'GET', timeout: 10, params: nil,
                                                      userpwd: 'user:password')

      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      extra_args = { 'args' => { userpwd: 'user:password' } }
      RestfulClient.get('posts', '/comments/123', nil, extra_args) do
        [] # default value to be returned on failure
      end
    end
  end

  describe 'custom headers' do
    it 'should allow sending custom headers to a single post request' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      custom_headers = { 'moshe' => 'OH MY GOD ~!!' }
      res = RestfulClient.post('locally', '/bounce_headers/moshe', {}, 'headers' => custom_headers)
      expect(res).to eq(custom_headers)
    end

    it 'should allow sending custom headers to a single get request' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      custom_headers = { 'moshe' => 'OH MY GOD ~!!' }
      res = RestfulClient.get('locally', '/bounce_headers/moshe', nil, 'headers' => custom_headers)
      expect(res).to eq(custom_headers)
    end

    it 'should allow sending custom headers to a single delete request' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      custom_headers = { 'moshe' => 'OH MY GOD ~!!' }
      res = RestfulClient.delete('locally', '/bounce_headers/moshe', {}, 'headers' => custom_headers)
      expect(res).to eq(custom_headers)
    end

    it 'should allow sending custom headers to a single put request' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      custom_headers = { 'moshe' => 'OH MY GOD ~!!' }
      res = RestfulClient.put('locally', '/bounce_headers/moshe', {}, 'headers' => custom_headers)
      expect(res).to eq(custom_headers)
    end
  end

  describe :PlainURL do
    it 'should be possible to get url from yml for custom calls' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      expect(RestfulClient.srv_url('posts')).to eq('http://1.2.3.4:8383/api/v0/')
    end
  end

  describe :NonJsonResponse do
    it 'should fail to block when server side returns a plain string rather than json' do
      RestfulClient.configure do |config|
        config.env_name = 'production'
        config.config_folder = 'spec/config'
      end

      RestfulClient.get('locally', '/non_json') { |msg| $some_global = msg }
      expect($some_global).to include('unexpected token')
    end
  end
end
