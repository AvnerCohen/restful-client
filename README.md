# RestfullClient  -- IN PROGRESS

An HTTP framework for micro-services based environment, build on top of [typhoeus](https://github.com/typhoeus/typhoeus) and [servicejynx](https://github.com/AvnerCohen/service-jynx)

## Installation


    gem 'restfull_client'

## Features

* Clean restfull api supporting http verbs (GET/PUT/POST/DELETE)
* Allows setting defaults for case of errors and SERVICE_DOWN event from Jynx
* Strcutured and configurable YAML for multiple service end points
* Build with Typheous, a fast and robuts http client, built on top of libcurl


## Usage

In your environment initializer:

<pre>
#with reporting method in case of errors (such as graylog)
p = proc { |*args| graylog_it(*args) }
RESTFULL_CLIENT = RestfullClient.new("path_to_service.yml", &p)
</pre>

Than use the service:

<pre>
RESTFULL_CLIENT.get("posts", "/comments/#{user.id}") do
 [] #default value to be returned on failure
end

#or
RESTFULL_CLIENT.post("posts", {comments: [1,2,4]}, "/comments/deleted/#{some_id}") do
 "ok" #default value to be returned on failure
end
</pre>

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
