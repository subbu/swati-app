defmodule Swati.Integrations.Attrs do
  def normalize(attrs) do
    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> normalize_allowed_tools()
    |> normalize_auth_type()
    |> normalize_type()
  end

  defp normalize_allowed_tools(attrs) do
    allowed_tools = Map.get(attrs, "allowed_tools")

    list =
      cond do
        is_list(allowed_tools) ->
          allowed_tools

        is_binary(allowed_tools) ->
          allowed_tools
          |> String.split(["\n", ","], trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        true ->
          []
      end

    Map.put(attrs, "allowed_tools", list)
  end

  defp normalize_auth_type(attrs) do
    auth_type = Map.get(attrs, "auth_type") || :none
    Map.put(attrs, "auth_type", to_enum(auth_type))
  end

  defp normalize_type(attrs) do
    type = Map.get(attrs, "type")

    normalized =
      case type do
        nil -> :mcp_streamable_http
        "" -> :mcp_streamable_http
        _ -> to_enum(type)
      end

    Map.put(attrs, "type", normalized)
  end

  defp to_enum(value) when is_atom(value), do: value

  defp to_enum(value) when is_binary(value) do
    case value do
      "mcp_streamable_http" -> :mcp_streamable_http
      "bearer" -> :bearer
      "none" -> :none
      "active" -> :active
      "disabled" -> :disabled
      _ -> :none
    end
  end
end
