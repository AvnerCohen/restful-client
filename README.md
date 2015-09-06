# RestfulClient

An HTTP framework for micro-services based environment, build on top of [typhoeus](https://github.com/typhoeus/typhoeus) and [servicejynx](https://github.com/AvnerCohen/service-jynx)

[![Build status](https://travis-ci.org/AvnerCohen/restful-client.png)](https://travis-ci.org/AvnerCohen/restful-client)

## Installation

    gem 'restful_client'

## Features

* Clean restful api supporting http verbs (GET/PUT/POST/DELETE)
* Manage Failures -  set stubs for case of errors and SERVICE_DOWN event from [Jynx](https://github.com/AvnerCohen/service-jynx)
* Strcutured and configurable YAML for multiple service end points
* Build using Typheous, a fast and robuts http client, built on top of libcurl
* Configurable timeouts for http request

## Configuration

Create the "restful_services.yml" file in your config folder.
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

### Possible flags

* use_jynx - Remove the integrated jynx-service protection (default: false)
* report_method - proc to be executed in the case of error
* env_name - environment name (production|staging|development etc..)
* config_folder - path to the configuration folder of the restful_services.yml file.
* user_agent - user agent... duh! (users_service|mobile_service|etc..)
* legacy_postfix - Legacy version accessed the restful_services.yml with an additional postfix in the yaml.

## Usage

In your environment initializer:

<pre>
      RestfulClient.configure do |config|
        config.env_name = Rails.env
        config.config_folder = "config"
      end
</pre>

When an error occurs, restful client will report it, as part of the configuration, you an provide it with a reporting hook service, such as graylog or airbrake or whatever you want.

Data from the report_method will be reported as ```func(klass_name, message, Exception)```

Consider the following example:

<pre>
      #reporting method
      def report_to_graylog(klass, message, e)
        Logger.warn "#{klass}::#{message}"
        $gelf_notifier.send_to_graylog2(e)
      end

      RestfulClient.configure do |config|
        config.env_name = ENV['RACK_ENV']
        config.config_folder = "config"
        config.user_agent = "my_service"
        #proc hock to the reporting method
        config.report_method = proc {|*args| report_to_graylog(*args) }
      end
</pre>


Default timeout for a call is set to 10 seconds, if you want to configure anything different:
<pre>

      RestfulClient.configure do |config|
        config.env_name = Rails.env
        config.config_folder = "#{Rails.root}/config"
        config.timeout = 5
      end  

</pre>

Than use the service:

<pre>
RestfulClient.get("posts", "/comments/#{user.id}") do
 [] #default value to be returned on failure
end

#or
RestfulClient.delete("posts", {comments: [1,2,4]}, "/comments/#{some_id}") do
 "ok" #default value to be returned on failure
end
</pre>

## Forward IP of client
In a complex micro services environment, when services are chained together, you might need to pass along the original IP of the client.
Implementation is based on a global $client_ip that can be set and will be assigned to the "X-Forwarded-For" http header.
So yeah, no JRuby support at this time.


## Reusing configuration
In some cases you might need to use, join or read the base URL of a given service:


Given:

````
  users:
    url: http://1.2.3.4:8383/api/v0/
````
<pre>

  RestfulClient.srv_url('posts') # ==> http://1.2.3.4:8383/api/v0/
</pre>

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
