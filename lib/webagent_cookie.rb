# Copyright (c) 2011, 2012, 2013, 2014, 2015 Solano Labs All Rights Reserved

# Version 2.6 of httpclient introduced irritative warning:
# "Cookie#domain returns dot-less domain name now. Use Cookie#dot_domain if you need "." at the beginning."
# See https://jira.slno.net/jira/browse/CICLI-61 for details.
# WebAgent is going to be deprecated in future, so this patch should not be harmful.
if (defined?(WebAgent::Cookie) &&
    WebAgent::Cookie.superclass.name == 'HTTP::Cookie' &&
    WebAgent::Cookie.instance_methods.include?(:domain))
  class WebAgent
    class Cookie
      def domain
        self.original_domain
      end 
    end 
  end 
end
