require 'active_support/core_ext/kernel/reporting'
require 'active_support/file_update_checker'
require 'rails/engine/configuration'

module Rails
  class Application
    class Configuration < ::Rails::Engine::Configuration
      attr_accessor :allow_concurrency, :asset_host, :asset_path, :assets, :autoflush_log,
                    :cache_classes, :cache_store, :consider_all_requests_local, :console,
                    :dependency_loading, :exceptions_app, :file_watcher, :filter_parameters,
                    :force_ssl, :helpers_paths, :logger, :log_formatter, :log_tags, :preload_frameworks,
                    :railties_order, :relative_url_root, :secret_token,
                    :serve_static_assets, :ssl_options, :static_cache_control, :session_options,
                    :time_zone, :reload_classes_only_on_change, :use_schema_cache_dump, :queue

      attr_writer :log_level
      attr_reader :encoding

      def initialize(*)
        super
        self.encoding = "utf-8"
        @allow_concurrency             = false
        @consider_all_requests_local   = false
        @filter_parameters             = []
        @helpers_paths                 = []
        @dependency_loading            = true
        @serve_static_assets           = true
        @static_cache_control          = nil
        @force_ssl                     = false
        @ssl_options                   = {}
        @session_store                 = :cookie_store
        @session_options               = {}
        @time_zone                     = "UTC"
        @log_level                     = nil
        @middleware                    = app_middleware
        @generators                    = app_generators
        @cache_store                   = [ :file_store, "#{root}/tmp/cache/" ]
        @railties_order                = [:all]
        @relative_url_root             = ENV["RAILS_RELATIVE_URL_ROOT"]
        @reload_classes_only_on_change = true
        @file_watcher                  = ActiveSupport::FileUpdateChecker
        @exceptions_app                = nil
        @autoflush_log                 = true
        @log_formatter                 = ActiveSupport::Logger::SimpleFormatter.new
        @use_schema_cache_dump         = true
        @queue                         = Rails::Queueing::Queue

        @assets = ActiveSupport::OrderedOptions.new
        @assets.enabled                  = false
        @assets.paths                    = []
        @assets.precompile               = [ Proc.new{ |path| !File.extname(path).in?(['.js', '.css']) },
                                             /(?:\/|\\|\A)application\.(css|js)$/ ]
        @assets.prefix                   = "/assets"
        @assets.version                  = ''
        @assets.debug                    = false
        @assets.compile                  = true
        @assets.digest                   = false
        @assets.manifest                 = nil
        @assets.cache_store              = [ :file_store, "#{root}/tmp/cache/assets/" ]
        @assets.js_compressor            = nil
        @assets.css_compressor           = nil
        @assets.initialize_on_precompile = true
        @assets.logger                   = nil
      end

      def compiled_asset_path
        "/"
      end

      def encoding=(value)
        @encoding = value
        silence_warnings do
          Encoding.default_external = value
          Encoding.default_internal = value
        end
      end

      def paths
        @paths ||= begin
          paths = super
          paths.add "config/database",    :with => "config/database.yml"
          paths.add "config/environment", :with => "config/environment.rb"
          paths.add "lib/templates"
          paths.add "log",                :with => "log/#{Rails.env}.log"
          paths.add "public"
          paths.add "public/javascripts"
          paths.add "public/stylesheets"
          paths.add "tmp"
          paths
        end
      end

      # Enable threaded mode. Allows concurrent requests to controller actions and
      # multiple database connections. Also disables automatic dependency loading
      # after boot, and disables reloading code on every request, as these are
      # fundamentally incompatible with thread safety.
      def threadsafe!
        @preload_frameworks = true
        @cache_classes = true
        @dependency_loading = false
        @allow_concurrency = true
        self
      end

      # Loads and returns the contents of the #database_configuration_file. The
      # contents of the file are processed via ERB before being sent through
      # YAML::load.
      def database_configuration
        require 'erb'
        YAML.load ERB.new(IO.read(paths["config/database"].first)).result
      end

      def log_level
        @log_level ||= Rails.env.production? ? :info : :debug
      end

      def colorize_logging
        ActiveSupport::LogSubscriber.colorize_logging
      end

      def colorize_logging=(val)
        ActiveSupport::LogSubscriber.colorize_logging = val
        self.generators.colorize_logging = val
      end

      def session_store(*args)
        if args.empty?
          case @session_store
          when :disabled
            nil
          when :active_record_store
            ActiveRecord::SessionStore
          when Symbol
            ActionDispatch::Session.const_get(@session_store.to_s.camelize)
          else
            @session_store
          end
        else
          @session_store = args.shift
          @session_options = args.shift || {}
        end
      end

      def whiny_nils=(*)
        ActiveSupport::Deprecation.warn "config.whiny_nils option " \
          "is deprecated and no longer works", caller
      end
    end
  end
end
