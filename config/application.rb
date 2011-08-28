require File.expand_path('../boot', __FILE__)

require 'rails/all'

require 'lib/rails-pinion-steps'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module Pinioned
  class Application < Rails::Application

    experimental_stack = ENV['BASE_RAILS'] != "true"
    #experimental_stack = true

    if experimental_stack
      puts "Using experimental stack"
      def default_middleware_stack
        require 'pinion'
        require 'rack/and-pinion'
        require 'pinion/and-rack'

        ActionDispatch::MiddlewareStack.new.tap do |middleware|
          #TODO: Pinion needs to handle exceptions well enough to support this
          #as a step
        end
      end

      def pinion_chain(routes)
        chain = Pinion::Chain.new
        chain.error_step = Pinion::Rails::ShowExceptions.new(config.consider_all_requests_local)

        if config.serve_static_assets
          chain.append Pinion::Rails::StaticFiles.new(paths.public.to_a.first)
        end
        unless config.allow_concurrency
          locker = chain.append Pinion::Rack::Lock.new
        end
        chain.append Pinion::Rack::MarkRequestStart.new
        chain.append Pinion::Rails::LogRequestBeginning.new
        chain.append Pinion::Rails::RemoteIp.new(
          config.action_dispatch.ip_spoofing_check,
          config.action_dispatch.trusted_proxies)
        before_callbacks = chain.append Pinion::Rails::BeforeCallbacks.new
        chain.append Pinion::Rails::QueryCacheStart.new

        #TODO: build needs to run these once, regardless
        unless config.cache_classes
          chain.append Pinion::Rails::BeforePrepareCallbacks.new
          chain.append Pinion::Rails::AfterPrepareCallbacks.new
        end

        # middleware.use config.session_store, config.session_options
        chain.append Pinion::Rails::SetupSession.new
        chain.append Pinion::Rails::SweepFlash.new
        chain.append Pinion::Rails::ParamsParser.new
        chain.append Pinion::Rails::Head.new
        chain.append Pinion::Rack::MethodOverride.new

        chain.append Pinion::AndRack.new(routes)

        if config.action_dispatch.best_standards_support
          chain.append Pinion::Rails::BestStandardsSupport.new(config.action_dispatch.best_standards_support)
        end

        chain.append Pinion::Rails::StoreFlash.new
        # middleware.use config.session_store, config.session_options
        chain.append Pinion::Rails::StoreSession.new
        chain.append Pinion::Rails::Cookies.new
        chain.append Pinion::Rails::ConnectionManagement.new
        chain.append Pinion::Rails::QueryCacheEnd.new
        after_callbacks = chain.append Pinion::Rails::AfterCallbacks.new
        before_callbacks.halted_next = after_callbacks
        chain.append Pinion::Rack::Sendfile.new(config.action_dispatch.x_sendfile_header)
        chain.append Pinion::Rails::LogFlush.new
        chain.append Pinion::Rack::RecordRuntime.new
        unless config.allow_concurrency
          chain.append Pinion::Rack::Unlock.new(locker.mutex)
        end
        chain.append Pinion::Rails::NoRouteCheck.new

        return Rack::AndPinion.new(chain)
      end

      def app
        @app ||=
          begin
            config.middleware = default_middleware_stack
            config.middleware.build(pinion_chain(routes))
          end
      end
      alias :build_middleware_stack :app

    else
      puts "Using base Rails stack"
    end


    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]
  end
end

