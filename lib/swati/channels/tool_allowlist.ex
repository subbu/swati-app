defmodule Swati.Channels.ToolAllowlist do
  alias Swati.Channels.Channel

  @spec allowed_tools(Channel.t()) :: [String.t()]
  def allowed_tools(%Channel{} = channel) do
    tools = map_value(channel.capabilities, "tools", :tools) || []

    tools
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp map_value(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end

  defp map_value(_map, _string_key, _atom_key), do: nil
end
