require 'pinion/step'

module ActionDispatch
  class Request
    def flash
      @env['action_dispatch.request.flash_hash'] ||= (session["flash"] || Flash::FlashHash.new)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    module QueryCache
      attr_accessor :query_cache_enabled
    end
  end
end

module Pinion
  module Rails
    class BestStandardsSupport < Pinion::Step
      def initialize(type)
        @header = case type
                  when true
                    "IE=Edge,chrome=1"
                  when :builtin
                    "IE=Edge"
                  when false
                    nil
                  end
      end

      def do_process(transaction)
        transaction.response.headers["X-UA-Compatible"] = @header
      end
    end

    class Head < Pinion::Step
      def do_process(transaction)
        if transaction.request.request_method == "HEAD"
          transaction.env["REQUEST_METHOD"] = "GET"
          transaction.env["rack.methodoverride.original_method"] = "HEAD"
        end
      end
    end

    class NoRouteCheck < Pinion::Step
      def do_process(transaction)
        if transaction.response.headers['X-Cascade'] == 'pass'
           raise ActionController::RoutingError, "No route matches #{transaction['PATH_INFO'].inspect}"
        end
      end
    end

    class ShowExceptions < ::ActionDispatch::ShowExceptions
      include Pinion::StepMixin

      def initialize(consider_all_requests_local)
        super(nil, consider_all_requests_local)
      end

      def do_process(transaction)
        exception = transaction.exceptions.last

        Rails.logger.fatal "Caught #{exception.class.name} - render? #{transaction['action_dispatch.show_exceptions']}"

        log_error(exception)

        if @consider_all_transaction.requests_local || transaction.request.local?
          Rails.logger.fatal "Render local"
          transaction.update_response_from_rack(*rescue_action_locally(transaction.request, exception))
        else
          Rails.logger.fatal "Render public"
          transaction.update_response_from_rack(*rescue_action_in_public(exception))
        end
      rescue Exception => failsafe_error
        $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
        FAILSAFE_RESPONSE
      end
    end

    class ParamsParser < ::ActionDispatch::ParamsParser
      include Pinion::StepMixin

      def initialize(parsers = nil)
        super(nil, parsers || {})
      end

      def do_process(transaction)
        if params = parse_formatted_parameters(transaction)
          transaction["action_dispatch.request.request_parameters"] = params
        end
      end
    end

    class SessionSteps < ::ActionDispatch::Session::CookieStore
      include Pinion::StepMixin

      def freeze #CookieStore freezes itself.  V irritating
      end

      def initialize(options = nil)
        super(nil, options || {})
      end
    end

    class SetupSession < SessionSteps
      def do_process(trans)
        prepare!(trans)
      end
    end

    class StoreSession < SessionSteps
      def set_cookie(trans, options)
        cookie_jar = (trans['action_dispatch.cookies'] ||= ActionDispatch::Cookies::CookieJar.build(trans.request))

        if cookie_jar[@key] != options[:value] || !options[:expires].nil?
          cookie_jar[@key] = options
        end
      end

      def do_process(trans)
        session_data = trans[ENV_SESSION_KEY]
        options = trans[ENV_SESSION_OPTIONS_KEY]

        if !session_data.is_a?(ActionDispatch::Session::AbstractStore::SessionHash) || session_data.loaded? || options[:expire_after]
          session_data.send(:load!) if session_data.is_a?(ActionDispatch::Session::AbstractStore::SessionHash) && !session_data.loaded?

          sid = options[:id] || generate_sid
          session_data = session_data.to_hash

          value = set_session(trans, sid, session_data)
          return response unless value

          cookie = { :value => value }
          unless options[:expire_after].nil?
            cookie[:expires] = Time.now + options.delete(:expire_after)
          end

          set_cookie(trans, cookie.merge!(options))
        end
      end
    end

    class SweepFlash < ::Pinion::Step
      def do_process(trans)
        if (session = trans['rack.session']) && (flash = session['flash'])
          flash.sweep
        end
      end
    end

    class StoreFlash < ::Pinion::Step
      #XXX: in original code, this is in an ensure block
      #XXX: currently, I think pinion will do Something Bad in the event of an
      #XXX: exception
      def do_process(trans)
        session    = trans['rack.session'] || {}
        flash_hash = trans['action_dispatch.request.flash_hash']

        if flash_hash && (!flash_hash.empty? || session.key?('flash'))
          session["flash"] = flash_hash
        end

        if session.key?('flash') && session['flash'].empty?
          session.delete('flash')
        end
      end
    end

    class Cookies < ::Pinion::Step
      HTTP_HEADER = "Set-Cookie".freeze
      TOKEN_KEY   = "action_dispatch.secret_token".freeze


      def do_process(trans)
        if cookie_jar = trans['action_dispatch.cookies']
          cookie_jar.write(trans.response.headers)
          if trans.response.headers[HTTP_HEADER].respond_to?(:join)
            trans.response.headers[HTTP_HEADER] = trans.response.headers[HTTP_HEADER].join("\n")
          end
        end
      end
    end

    class CallbacksStep < ::ActionDispatch::Callbacks
      include Pinion::StepMixin

      def initialize()
        @next = nil
        @callback_exec = false
        super(false)
      end

      def do_process(trans = nil)
        build_executor unless @callback_exec
        execute_callbacks
      end

      def callback_chain
        get_callback_chain
      end

      def get_callback_chain
        _call_callbacks
      end
    end

    class BeforeCallbacks < CallbacksStep
      def initialize(halt_jump = nil)
        @halted_next = halt_jump
        super()
      end
      attr_accessor :halted_next, :next

      def process(trans = nil)
        if do_process(trans)
          return @next
        else
          return @halted_next
        end
      end

      def build_executor
        method_def = <<-RUBY_EVAL
          def execute_callbacks
            value = nil
            halted = false
            #{callback_chain.map do |callback|
              callback.start
            end.compact.join("\n")}
            return !halted
          end
        RUBY_EVAL
        @callback_exec = true
        class_eval method_def, __FILE__, __LINE__ + 1
      end
    end

    class BeforePrepareCallbacks < BeforeCallbacks
      def get_callback_chain
        _prepare_callbacks
      end
    end

    class AfterCallbacks < CallbacksStep
      def callback_chain
        get_callback_chain.enum_for(:reverse_each)
      end

      def build_executor
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def execute_callbacks
            value = nil
            halted = false
            #{callback_chain.map do |callback|
              callback.end
            end.compact.join("\n")}
          end
        RUBY_EVAL
        @callback_exec = true
      end
    end

    class AfterPrepareCallbacks < AfterCallbacks
      def get_callback_chain
        _prepare_callbacks
      end
    end

    class ConnectionManagement < ::Pinion::Step
      def do_process(trans)
        unless trans["rack.test"]
          ActiveRecord::Base.clear_active_connections!
        end
      end
    end

    class QueryCacheStart < ::Pinion::Step
      def do_process(trans)
        trans["activerecord.oldcachestate"] = ActiveRecord::Base.connection.query_cache_enabled
        ActiveRecord::Base.connection.query_cache_enabled = true
      end
    end

    class QueryCacheEnd < ::Pinion::Step
      def do_process(trans)
        ActiveRecord::Base.connection.query_cache_enabled = trans["activerecord.oldcachestate"]
        ActiveRecord::Base.connection.clear_query_cache
      end
    end

    class RemoteIp < ::Pinion::Step
      def initialize(check_ip_spoofing, trusted_proxies)
        @check_ip_spoofing = check_ip_spoofing
        @trusted_proxies = trusted_proxies
        super()
      end

      def do_process(trans)
        trans["action_dispatch.remote_ip"] =
          ::ActionDispatch::RemoteIp::RemoteIpGetter.new(
            trans.env, @check_ip_spoofing, @trusted_proxies)
      end
    end

    class LogRequestBeginning < ::Pinion::Step
      def do_process(tr)
        path = tr.request.fullpath

        ::Rails.logger.info "\n\nStarted #{tr.request.request_method} \"#{path}\" " \
          "for #{tr.request.ip} at #{Time.now.to_default_s}"
      end
    end

    class LogFlush < ::Pinion::Step
      def do_process(tr)
        ActiveSupport::LogSubscriber.flush_all!
      end
    end

    class StaticFiles < ::Pinion::Step
      require 'time'
      require 'rack/utils'
      require 'rack/mime'

      FILE_METHODS = %w(GET HEAD).freeze

      def initialize(root)
        @root = root
        @served_next = nil
      end

      attr_accessor :served_next

      def process(trans)
        path   = trans['PATH_INFO'].chomp('/')
        method = trans['REQUEST_METHOD']
        full_path = ::File.join(@root, ::Rack::Utils.unescape(path))

        if FILE_METHODS.include?(method)
          if file_exist?(full_path)
            serve_path(full_path, trans)
            return @served_next
          else
            cached_path = directory_exist?(full_path) ? "#{path}/index" : path
            cached_path += ::ActionController::Base.page_cache_extension

            if file_exist?(cached_path)
              trans['PATH_INFO'] = cached_path
              serve_path(cached_path)
              return @served_next
            end
          end
        end

        return @next
      end

      def file_exist?(full_path)
        File.file?(full_path) && File.readable?(full_path)
      end

      def directory_exist?(full_path)
        File.directory?(full_path) && File.readable?(full_path)
      end

      def serve_path(path, trans)
        return forbidden(trans) if path.include? ".."

        begin
          serving(path, trans)
        rescue SystemCallError
          not_found(path, trans)
        end
      end

      def forbidden(trans)
        trans.response.status = 403
        trans.response.body = ["Forbidden\n"]
        trans.response.headers.merge!("Content-Type" => "text/plain",
          "Content-Length" => trans.response.body.first.size.to_s,
          "X-Cascade" => "pass")
      end

      def not_found(path, trans)
        trans.response.status = 404
        trans.response.body = ["File not found: #{@path_info}\n"]
        trans.response.headers.merge!("Content-Type" => "text/plain",
          "Content-Length" => trans.response.body.first.size.to_s,
          "X-Cascade" => "pass")
      end

      def serving(path, trans)
        if size = File.size?(path)
          body = StaticFile.new(path)
        else
          body = [File.read(path)]
          size = Utils.bytesize(body.first)
        end

        trans.response.status = 200
        trans.response.headers.merge!(
          "Last-Modified"  => File.mtime(path).httpdate,
          "Content-Type"   => ::Rack::Mime.mime_type(File.extname(path), 'text/plain'),
          "Content-Length" => size.to_s)
        trans.response.body = body
      end

      class StaticFile
        def initialize(path)
          @path = path
        end

        attr_accessor :path

        alias :to_path :path

        def each
          File.open(@path, "rb") { |file|
            while part = file.read(8192)
              yield part
            end
          }
        end
      end

    end
  end

  module Rack
    class Lock < ::Pinion::Step
      def initialize(mutex = nil)
        @mutex = mutex || Mutex.new
      end
      attr_reader :mutex

      def do_process(tr)
        tr["rack.multithread.old"], tr["rack.multithread"] =
          tr["rack.multithread"], false
        @mutex.lock
      end
    end

    class Unlock < ::Pinion::Step
      def initialize(mutex = nil)
        @mutex = mutex || Mutex.new
      end
      attr_reader :mutex

      def do_process(tr)
        tr["rack.multithread"] = tr["rack.multithread.old"]
        @mutex.unlock
      end
    end

    class MarkRequestStart < ::Pinion::Step
      def do_process(tr)
        tr["runtime.start"] = Time.new
      end
    end

    class RecordRuntime < ::Pinion::Step
      def initialize(name = nil)
        @header_name = "X-Runtime"
        @header_name << "-#{name}" if name
      end

      def do_process(tr)
        request_time = Time.now - tr["runtime.start"]

        if !tr.response.headers.has_key?(@header_name)
          tr.response.headers[@header_name] = "%0.6f" % request_time
        end
      end
    end

    class Sendfile < Pinion::Step
      def initialize(variation)
        @variation = variation
        super()
      end

      def do_process(tr)
        body = tr.response.body
        if tr.response.body.respond_to?(:to_path)
          case type = variation(tr)
          when 'X-Accel-Redirect'
            path = ::File.expand_path(tr.response.body.to_path)
            if url = map_accel_path(tr, path)
              tr.response.headers[type] = url
              tr.response.body = []
            else
              tr['rack.errors'] << "X-Accel-Mapping header missing"
            end
          when 'X-Sendfile', 'X-Lighttpd-Send-File'
            path = ::File.expand_path(tr.response.body.to_path)
            tr.response.headers[type] = path
            tr.response.body = []
          when '', nil
          else
            tr['rack.errors'] << "Unknown x-sendfile variation: '#{variation}'.\n"
          end
        end
      end

      def variation(env)
        @variation ||
          env['sendfile.type'] ||
          env['HTTP_X_SENDFILE_TYPE']
      end

      def map_accel_path(env, file)
        if mapping = env['HTTP_X_ACCEL_MAPPING']
          internal, external = mapping.split('=', 2).map{ |p| p.strip }
          file.sub(/^#{internal}/i, external)
        end
      end

    end

    class MethodOverride < Pinion::Step
      HTTP_METHODS = %w(GET HEAD PUT POST DELETE OPTIONS)
      METHOD_OVERRIDE_PARAM_KEY = "_method".freeze
      HTTP_METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE".freeze

      def do_process(tr)
        if tr.request.request_method == "POST"
          method = tr.request.POST[METHOD_OVERRIDE_PARAM_KEY] || tr.env[HTTP_METHOD_OVERRIDE_HEADER]
          method = method.to_s.upcase
          if HTTP_METHODS.include?(method)
            tr.env["rack.methodoverride.original_method"] = tr.env["REQUEST_METHOD"]
            tr.env["REQUEST_METHOD"] = method
          end
        end
      end
    end
  end

end
