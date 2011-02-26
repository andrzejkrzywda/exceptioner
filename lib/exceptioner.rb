require 'exceptioner/core_ext/class/attribute'
require 'exceptioner/core_ext/module/attribute_accessors'
require 'exceptioner/core_ext/string/inflections'
require 'exceptioner/dispatchable'
require 'exceptioner/version'
require 'exceptioner/railtie' if defined?(Rails::Railtie)

module Exceptioner
  extend Dispatchable

  class ExceptionerError < StandardError; end

  autoload :Middleware,       'exceptioner/middleware'
  autoload :Notifier,         'exceptioner/notifier'
  autoload :Utils,            'exceptioner/utils'
  
  module Transport
    autoload :Mail,     'exceptioner/transport/mail/mail'
    autoload :Jabber,   'exceptioner/transport/jabber/jabber'
    autoload :Redmine,  'exceptioner/transport/redmine/redmine'
    autoload :IRC,      'exceptioner/transport/irc/irc'
    autoload :Campfire, 'exceptioner/transport/campfire/campfire'
  end

  # Define how to deliver exceptions data. 
  # For example :mail, :jabber, :irc, :campfirenow
  mattr_accessor :transports
  @@transports = [:mail]

  # If true exceptions raised by local requests will be delivered
  # Note it is Rails 2.x specific setting
  mattr_accessor :dispatch_local_requests
  @@dispatch_local_requests = false

  # Name of current environment.
  # For rails it would be development, test or production.
  # It's included in exception notification.
  # You can also combine it with development_environments to decide
  # when to handle exceptions by Exceptioner.
  mattr_accessor :environment_name

  # Define development environment. For these environments exceptions will not
  # be handled by Exceptioner.
  mattr_accessor :development_environments
  @@development_environments = %w[development test cucumber]

  DEFAULT_IGNORED_EXCEPTIONS = %w[
    ActiveRecord::RecordNotFound
    ActionController::RoutingError
    ActionController::UnknownAction
  ]

  # Array of ignored exceptions.
  # By default it's set to exceptions defined in DEFAULT_IGNORED_EXCEPTIONS
  mattr_accessor :ignore
  @@ignore = DEFAULT_IGNORED_EXCEPTIONS.dup

  def self.setup
    yield self if block_given?
    init_transports
  end

  def self.init
    add_default_dispatchers
  end

  def self.mail
    Transport::Mail
  end

  def self.jabber
    Transport::Jabber
  end

  def self.irc
    Transport::Irc
	end

  def self.redmine
    Transport::Redmine
  end

  def self.campfire
    Transport::Campfire
  end

  def self.notify(exception, options = {})
    Notifier.dispatch(exception, options)
  end

  def self.config
    self
  end

  def self.reset_dispatchers
    clear_dispatchers
    add_default_dispatchers
  end

  def self.add_default_dispatchers
    disallow_development_environment
    disallow_ignored_exceptions
  end

  def self.disallow_development_environment 
    dispatch do |exception|
      ! development_environments.include?(environment_name)  
    end
  end

  def self.disallow_ignored_exceptions
    dispatch do |exception|
      ! Array(ignore).collect(&:to_s).include?(exception.class.name)
    end
  end

  def self.init_transports
    Exceptioner::Utils.classify_transports(config.transports).each do |transport_class|
      transport_instance(transport_class).configure
    end
  end

  def self.transport_instance(transport_class)
    @@transport_instances ||= { }
    @@transport_instances[transport_class.to_s] ||= transport_class.new
  end
end

require 'exceptioner/support/rails2' if defined?(Rails::VERSION::MAJOR) && Rails::VERSION::MAJOR == 2

Exceptioner.init
