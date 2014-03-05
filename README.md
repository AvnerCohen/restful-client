# RestfullClient  -- IN PROGRESS

An HTTP framework for micro-services based environment, build on top of [typhoeus](https://github.com/typhoeus/typhoeus) and [servicejynx](https://github.com/AvnerCohen/service-jynx)

## Installation


    gem 'RestfullClient'

## Features

* Clean restfull api supporting http verbs (GET/PUT/POST/DELETE)
* Allows setting defaults for case of errors and SERVICE_DOWN event from Jynx
* Strcutured and configurable YAML for multiple service end points
* Build with Typheous, a fast and robuts http client, built on top of libcurl


## Usage

In your environment initializer:

<pre>
      RestfullClient.configure do |config|
        config.file_name = "config/services.yml"
      end
</pre>



<pre>
      RestfullClient.configure do |config|
        config.file_name = "config/services.yml"
        config.report_method = proc {|*args| @@some_global = *args }
      end
</pre>

Than use the service:

<pre>
RestfullClient.get("posts", "/comments/#{user.id}") do
 [] #default value to be returned on failure
end

#or
RestfullClient.delete("posts", {comments: [1,2,4]}, "/comments/#{some_id}") do
 "ok" #default value to be returned on failure
end
</pre>

## Forward IP of client
In a complex micro services environment, when services are chained together, you might need to pass along the original IP of the client.
Implementaion is based on a global $client_ip that can be set and will be assigned to the "X-Forwarded-For" http header.
So yeah, no JRuby support at this time.

## Configuration

Configuration for the various service is based on top of YAML that configures the http service endpoints and ServiceJynx setup:

<pre>
development: &development
  users:
    url: http://1.2.3.4:7711/api/v1/
    time_window_in_seconds: 20
    max_errors: 10
    grace_period: 60    

production: &production
  users:
    url: http://1.2.3.4:7711/api/v0/
    time_window_in_seconds: 20
    max_errors: 10
    grace_period: 60    

</pre>


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
