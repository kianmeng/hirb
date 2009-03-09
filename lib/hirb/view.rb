module Hirb
  module View
    class<<self
      attr_accessor :config, :render_method

      # Overrides irb's output method with Hirb's.
      def enable
        load_config
        ::IRB::Irb.class_eval do
          alias :non_hirb_render_output  :output_value
          def output_value
            Hirb::View.render_output(@context.last_value) || non_hirb_render_output
          end
        end
      end
      
      # Disable's Hirb's output method by reverting back to irb's.
      def disable
        ::IRB::Irb.class_eval do
          alias :output_value :non_hirb_render_output
        end
      end
      
      def render_output(output, options={})
        if (formatted_output = format_output(output, options))
          render_method.call(formatted_output)
          true
        else
          false
        end
      end
      
      def render_method
        @render_method ||= lambda {|output| puts output}
      end
      
      def console_render_output(output, options={})
        # iterates over format_output options that aren't :options
        real_options = [:method, :class].inject({}) do |h, e|
          h[e] = options.delete(e) if options[e]
          h
        end
        render_output(output, real_options.merge(:options=>options))
      end

      def format_output(output, options={})
        output_class = determine_output_class(output)
        options = output_class_options(output_class).merge(options)
        args = options[:options] ? [options[:options]] : []
        if options[:method]
          new_output = send(options[:method], output, *args)
        elsif options[:class] && (view_class = Util.any_const_get(options[:class]))
          new_output = view_class.render(output, *args)
        end
        new_output
      end

      def load_config
        self.config = default_config.merge(Hirb.config[:view] || {})
      end
      
      # Stores user-defined view options, mapping stringfied classes to their view options.
      def config=(value)
        @output_class_config = nil #reset internal config
        @config = value
      end

      # Internal view options built from user-defined ones. Options are built by recursively merging options from oldest
      # ancestors to the most recent ones.
      def output_class_options(output_class)
        @output_class_config ||= {}
        @output_class_config[output_class] ||= 
          begin
            output_ancestors_with_config = output_class.ancestors.map {|e| e.to_s}.select {|e| config.has_key?(e)}
            @output_class_config[output_class] = output_ancestors_with_config.reverse.inject({}) {|h, klass|
              h.update(config[klass])
            }
          end
        @output_class_config[output_class]
      end
      
      def output_class_config; @output_class_config; end
      
      def default_config
        Hirb::Views.constants.inject({}) {|h,e|
          output_class = e.to_s.gsub("_", "::")
          if Hirb::Views.const_get(e).respond_to?(:render)
            h[output_class] = {:class=>"Hirb::Views::#{e}"}
          end
          h
        }
      end

      def determine_output_class(output)
        if output.is_a?(Array)
          output[0].class
        else
          output.class
        end
      end
    end
  end
  
  # Namespace for autoloaded views
  module Views
  end
end
