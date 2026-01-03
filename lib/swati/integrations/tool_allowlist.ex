defmodule Swati.Integrations.ToolAllowlist do
  alias Swati.Integrations.Integration

  @spec allowed_tools(Integration.t()) :: [String.t()]
  def allowed_tools(%Integration{} = integration) do
    integration.allowed_tools
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&apply_prefix(integration, &1))
  end

  defp apply_prefix(%Integration{tool_prefix: prefix}, tool)
       when is_binary(prefix) and prefix != "" do
    prefixed = "#{prefix}/"

    if String.starts_with?(tool, prefixed) do
      tool
    else
      prefixed <> tool
    end
  end

  defp apply_prefix(_integration, tool), do: tool
end
