# Copyright (C) 2013 VMware, Inc.
require 'rbvmomi' if Puppet.features.vsphere? and ! Puppet.run_mode.master?
gem 'rest-client', '=1.6.7' # pending changes for self-signed certs in v 1.7.2 ?
require 'rest_client' if Puppet.features.restclient? and ! Puppet.run_mode.master?

module PuppetX::Puppetlabs::Transport
  class Vsphere
    attr_accessor :vim, :rest
    attr_reader :name, :token

    def initialize(opts)
      @name    = opts[:name]
      options  = opts[:options] || {}
      @options = options.inject({}){|h, (k, v)| h[k.to_sym] = v; h}
      @options[:host]     = opts[:server]
      @options[:user]     = opts[:username]
      @options[:password] = opts[:password]
      @options[:timeout]  = opts[:timeout] || 300
      Puppet.debug("#{self.class} initializing connection to: #{@options[:host]}")
    end

    def connect
      @vim ||= begin
        Puppet.debug("#{self.class} opening connection to #{@options[:host]}")
        RbVmomi::VIM.connect(@options)
      rescue Exception => e
        Puppet.warning("#{self.class} connection to #{@options[:host]} failed; retrying once...")
        RbVmomi::VIM.connect(@options)
      end

      vapi
      @vim
    end

    def vapi
      if @vim.serviceContent.about.version >= '6.0.0'
        @rest ||= RestClient::Resource.new(
          "https://#{@options[:host]}/rest",
          :user => @options[:user],
          :password => @options[:password],
          :verify_ssl => OpenSSL::SSL::VERIFY_NONE,
          :ssl_version => 'SSLv23',
          :headers => {
              :accept => "application/json"
          },
          :timeout => @options[:timeout].to_i
        )
        url = '/com/vmware/cis/session'

        response = @rest[url].post(nil)
        @cookies = response.cookies
        @rest
      end
    end

    def close
      Puppet.debug("#{self.class} closing connection to: #{@options[:host]}")
      @vim.close if @vim
      if @rest
        @rest['/com/vmware/cis/session'].delete({:cookies => @cookies})
        @cookies = nil
        @rest = nil
      end
    end
  end
end
