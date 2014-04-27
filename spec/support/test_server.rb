require 'rubygems'
require 'rack'
require 'json'

module MyApp
  module Test
    class Server
      @@counter = 0
      def call(env)
        path = Rack::Utils.unescape(env['PATH_INFO'])
        ### Hacky just to allow sending a global counter
        if path == "/api/v0/a/a/a/b"
          @@counter = @@counter+1
          sleep 3
          [ 500, {"Content-Type" => "application/json"}, {counter: @@counter}.to_json ]
        elsif path == "/api/v0/bounce"
          [ 200, {'Content-Type' => 'text/plain'}, env['rack.input'].gets ]
        elsif path == "/api/v0/non_existing"
          [ 404, {'Content-Type' => 'text/plain'}, {}.to_json ]
        elsif path == "/api/v0/client_error"
          [ 400, {'Content-Type' => 'text/plain'}, {}.to_json ]
        elsif path =~ /\/api\/v0\/bounce_headers/
            ## this is what rack request is doing to custom headers
            base_name = path.split("/").last
            header_name = "HTTP_#{base_name.upcase}"
          [ 200, {'Content-Type' => 'text/plain'}, {"#{base_name}" => env[header_name]}.to_json ]
        else
          [ 200, {'Content-Type' => 'text/plain'}, {counter: @@counter}.to_json ]
        end
      end
    end
  end
end