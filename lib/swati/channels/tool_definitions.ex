defmodule Swati.Channels.ToolDefinitions do
  @moduledoc false

  @definitions %{
    "channel.message.send" => %{
      "name" => "channel.message.send",
      "description" => "Send a message to the current channel/session.",
      "parameters" => %{
        "type" => "object",
        "properties" => %{
          "session_id" => %{
            "type" => "string",
            "description" => "Session id (defaults to current)."
          },
          "text" => %{"type" => "string", "description" => "Plain text message body."},
          "payload" => %{
            "type" => "object",
            "description" => "Structured payload for the channel adapter."
          },
          "type" => %{"type" => "string", "description" => "Event type override."},
          "source" => %{"type" => "string", "description" => "Event source override."},
          "to" => %{"type" => "string", "description" => "Optional recipient override."},
          "subject" => %{"type" => "string", "description" => "Optional subject (email)."},
          "thread_id" => %{
            "type" => "string",
            "description" => "Optional thread/conversation id."
          }
        }
      }
    },
    "channel.thread.fetch" => %{
      "name" => "channel.thread.fetch",
      "description" => "Fetch thread context for the current session.",
      "parameters" => %{
        "type" => "object",
        "properties" => %{
          "session_id" => %{
            "type" => "string",
            "description" => "Session id (defaults to current)."
          },
          "thread_id" => %{"type" => "string", "description" => "Thread/conversation id."},
          "limit" => %{"type" => "integer", "description" => "Optional max messages to return."}
        }
      }
    },
    "channel.thread.close" => %{
      "name" => "channel.thread.close",
      "description" => "Close a thread or mark the conversation as resolved.",
      "parameters" => %{
        "type" => "object",
        "properties" => %{
          "session_id" => %{
            "type" => "string",
            "description" => "Session id (defaults to current)."
          },
          "thread_id" => %{"type" => "string", "description" => "Thread/conversation id."},
          "reason" => %{"type" => "string", "description" => "Reason for closing the thread."},
          "metadata" => %{"type" => "object", "description" => "Additional metadata."}
        }
      }
    },
    "channel.handoff.request" => %{
      "name" => "channel.handoff.request",
      "description" => "Request a human handoff for the current session.",
      "parameters" => %{
        "type" => "object",
        "properties" => %{
          "session_id" => %{
            "type" => "string",
            "description" => "Session id (defaults to current)."
          },
          "case_id" => %{"type" => "string", "description" => "Case id (defaults to current)."},
          "target_channel_id" => %{"type" => "string", "description" => "Target channel id."},
          "target_endpoint_id" => %{"type" => "string", "description" => "Target endpoint id."},
          "reason" => %{"type" => "string", "description" => "Reason for handoff."},
          "metadata" => %{"type" => "object", "description" => "Additional metadata."}
        }
      }
    },
    "channel.handoff.transfer" => %{
      "name" => "channel.handoff.transfer",
      "description" => "Transfer the session to a human or target endpoint.",
      "parameters" => %{
        "type" => "object",
        "properties" => %{
          "session_id" => %{
            "type" => "string",
            "description" => "Session id (defaults to current)."
          },
          "case_id" => %{"type" => "string", "description" => "Case id (defaults to current)."},
          "target_channel_id" => %{"type" => "string", "description" => "Target channel id."},
          "target_endpoint_id" => %{"type" => "string", "description" => "Target endpoint id."},
          "reason" => %{"type" => "string", "description" => "Reason for transfer."},
          "metadata" => %{"type" => "object", "description" => "Additional metadata."}
        }
      }
    }
  }

  @spec definitions([String.t()]) :: [map()]
  def definitions(tool_names) when is_list(tool_names) do
    tool_names
    |> Enum.map(&Map.get(@definitions, &1))
    |> Enum.reject(&is_nil/1)
  end

  def definitions(_tool_names), do: []
end
