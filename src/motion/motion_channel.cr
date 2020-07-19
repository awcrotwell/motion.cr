require "json"

abstract class Amber::WebSockets::Channel; end

module Motion
  class Channel < Amber::WebSockets::Channel
    # include ActionCableExtentions::DeclarativeNotifications
    # include ActionCableExtentions::DeclarativeStreams
    # include ActionCableExtentions::LogSuppression

    # ACTION_METHODS = Set.new(["process_motion"]).freeze
    # private_constant :ACTION_METHODS

    # Don't use the ActionCable huertistic for deciding what actions can be
    # called from JavaScript. Instead, hard-code the list so we can make other
    # methods public without worrying about them being called from JavaScript.
    # def self.action_methods
    #   ACTION_METHODS
    # end

    getter component_connection : Motion::ComponentConnection?

    def handle_joined(client_socket, message)
      pp "handle join"
      # puts message
      params = JSON.parse message["identifier"].to_s
      state, client_version = params["state"].to_s, params["version"].to_s

      # TODO: Ensure npm & shard versions are the same
      # if Gem::Version.new(Motion::VERSION) < Gem::Version.new(client_version)
      #   raise IncompatibleClientError.new(Motion::VERSION, client_version)
      # end

      # TODO: Pass in Motion.config.log_helper
      @component_connection =
        ComponentConnection.from_state(state)

      synchronize
    rescue e : Exception
      # reject

      handle_error(e, "connecting a component")
    end

    def handle_leave(client_socket)
      # TODO: Remove not_nil
      pp "unsubscribe"
      component_connection.not_nil!.close

      @component_connection = nil
    end

    def handle_message(client_socket, message)
      return handle_leave(client_socket) if message["payload"]["message"]["command"] == "unsubscribe"
      identifier, data, action =
        parse_motion(message["payload"])

      case action
      when "process_motion"
        process_motion(identifier, data) if data
      end
      synchronize(message["topic"], true)
    end

    def process_motion(identifier, data : JSON::Any)
      motion, raw_event = data["name"], data["event"]

      if (cc = component_connection)
        cc.process_motion(motion.to_s, Motion::Event.from_raw(raw_event))
      else
        raise "NoComponentConnectionError"
      end
    end

    # def process_broadcast(broadcast, message)
    #   component_connection.process_broadcast(broadcast, message)
    #   synchronize
    # end

    # def process_periodic_timer(timer)
    #   component_connection.process_periodic_timer(timer)
    #   synchronize
    # end

    private def synchronize(topic = nil, broadcast = false)
      # streaming_from component_connection.broadcasts,
      #   to: :process_broadcast

      # periodically_notify component_connection.periodic_timers,
      #   via: :process_periodic_timer
      if broadcast
        proc = ->(component : Motion::Base) {
          html = html_transformer.add_state_to_html(component, component.rerender)
          rebroadcast!({
            subject: "message_new",
            topic:   topic,
            payload: {
              html: html,
            },
          })
        }

        # TODO: Remove not_nil
        component_connection.not_nil!.if_render_required(proc)
      end
    end

    # TODO: pass error in as an argument: , error: error
    private def handle_error(error, context)
      log_helper.error("An error occurred while #{context} & #{error}")
    end

    private def log_helper
      @log_helper ||= Motion::Logger.new # TODO: .for_channel(self)
    end

    private def parse_motion(payload)
      identifier = if (_identifier = payload["message"]["identifier"]?)
                     JSON.parse(_identifier.to_s)
                   else
                     nil
                   end

      data = if (_data = payload["message"]["data"]?)
               JSON.parse(_data.to_s)
             else
               nil
             end

      action = data ? data["action"]? : nil

      [identifier, data, action]
    end

    private def html_transformer
      @html_transformer ||= Motion::HTMLTransformer.new
    end

    # Memoize the renderer on the connection so that it can be shared accross
    # all components. `ActionController::Renderer` is already thread-safe and
    # designed to be reused.
    # private def renderer
    #   connection.instance_eval do
    #     @_motion_renderer ||= Motion.build_renderer_for(self)
    #   end
    # end
  end
end
