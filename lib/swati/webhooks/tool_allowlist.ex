defmodule Swati.Webhooks.ToolAllowlist do
  alias Swati.Webhooks.Webhook

  @spec allowed_tools(Webhook.t()) :: [String.t()]
  def allowed_tools(%Webhook{} = webhook) do
    webhook.tool_name
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
  end
end
