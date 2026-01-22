defmodule SwatiWeb.Internal.RuntimeError do
  @moduledoc false

  alias Ecto.Changeset
  alias SwatiWeb.CoreComponents

  @type t :: %{
          code: String.t(),
          message: String.t(),
          action: String.t() | nil,
          retryable: boolean(),
          details: map() | nil
        }

  @spec to_response(term()) :: {integer() | atom(), t()}
  def to_response(reason) do
    case reason do
      %Changeset{} = changeset ->
        {:unprocessable_entity,
         error(
           "invalid_params",
           "Invalid runtime resolve request.",
           "fix_request",
           false,
           changeset_details(changeset)
         )}

      :endpoint_not_found ->
        {:not_found,
         error(
           "endpoint_not_found",
           "Endpoint not found for channel.",
           "provision_endpoint",
           false
         )}

      :customer_identity_missing ->
        {:unprocessable_entity,
         error(
           "customer_identity_missing",
           "Missing customer identity.",
           "provide_customer_identity",
           false
         )}

      :agent_missing ->
        {:unprocessable_entity,
         error(
           "agent_missing",
           "No active agent configured.",
           "assign_agent",
           false
         )}

      :agent_not_published ->
        {:unprocessable_entity,
         error(
           "agent_not_published",
           "Agent has no published version.",
           "publish_agent",
           false
         )}

      :agent_channel_disabled ->
        {:unprocessable_entity,
         error(
           "agent_channel_disabled",
           "Agent not enabled for channel.",
           "enable_agent_channel",
           false
         )}

      :agent_channel_scope_denied ->
        {:unprocessable_entity,
         error(
           "agent_channel_scope_denied",
           "Agent scope excludes the endpoint.",
           "update_agent_channel_scope",
           false
         )}

      atom when is_atom(atom) ->
        {:unprocessable_entity,
         error(
           Atom.to_string(atom),
           "Runtime resolve failed.",
           "check_runtime_config",
           false
         )}

      _ ->
        {:internal_server_error,
         error(
           "runtime_error",
           "Runtime resolve failed.",
           "check_server_logs",
           true
         )}
    end
  end

  defp error(code, message, action, retryable, details \\ nil) do
    %{
      code: code,
      message: message,
      action: action,
      retryable: retryable,
      details: details
    }
  end

  defp changeset_details(%Changeset{} = changeset) do
    errors =
      Changeset.traverse_errors(changeset, fn {message, opts} ->
        CoreComponents.translate_error({message, opts})
      end)

    %{fields: errors}
  end
end
