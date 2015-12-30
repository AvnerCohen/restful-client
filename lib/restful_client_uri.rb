require 'uri'

module RestfulClientUri
  module_function

  ## This is totally wierd, but File.join just does what you need while URI.join as much too strict.
  def uri_join(url, path)
    File.join(url, path).to_s
  end
end
