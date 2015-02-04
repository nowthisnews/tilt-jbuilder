require 'tilt'
require 'jbuilder'

module Tilt
  class Jbuilder < ::Jbuilder
    def initialize(scope, *args, &block)
      @scope = scope
      super(*args, &block)
    end

    def partial!(template_name, locals = {})
      locals.merge! :json => self
      template_path = locals.extract!(:template_path)[:template_path]
      view_path = @scope.instance_variable_get('@_jbuilder_view_path') || template_path
      file = fetch_partial_path(template_name.to_s, view_path)
      template = ::Tilt::JbuilderTemplate.new(file, nil, view_path: view_path)
      template.render(@scope, locals)
    end

    private
    def fetch_partial_path(file, view_path)
      view_path ||= ::Dir.pwd
      ::Dir[::File.join(view_path, partialized(file) + ".{*.,}jbuilder")].first
    end

    def partialized(path)
      partial_file = path.split("/")
      partial_file[-1] = "_#{partial_file[-1]}" unless partial_file[-1].start_with?("_")
      partial_file.join("/")
    end
  end

  class JbuilderTemplate < Template
    self.default_mime_type = 'application/json'

    def self.engine_initialized?
      defined? ::Jbuilder
    end

    def initialize_engine
      require_template_library 'jbuilder'
    end

    def prepare; end

    def evaluate(scope, locals, &block)
      scope ||= Object.new
      ::Tilt::Jbuilder.encode(scope) do |json|
        context = scope.instance_eval { binding }
        set_locals(locals, scope, context)
        if data.kind_of?(Proc)
          return data.call(::Tilt::Jbuilder.new(scope))
        else
          file.is_a?(String) ? eval(data, context, file) : eval(data, context)
        end
      end
    end

    private
    def set_locals(locals, scope, context)
      view_path = options[:view_path]
      scope.send(:instance_variable_set, '@_jbuilder_view_path', view_path)
      scope.send(:instance_variable_set, '@_jbuilder_locals', locals)
      scope.send(:instance_variable_set, '@_tilt_data', data)
      set_locals = locals.keys.map { |k| "#{k} = @_jbuilder_locals[#{k.inspect}]" }.join("\n")
      eval set_locals, context
    end
  end

  register Tilt::JbuilderTemplate, 'jbuilder'
end
