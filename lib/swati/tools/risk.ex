defmodule Swati.Tools.Risk do
  @default %{
    "access" => "read",
    "reversible" => true,
    "financial" => "none",
    "pii" => "none",
    "requires_approval" => false
  }

  @spec default() :: map()
  def default, do: @default

  @spec normalize(map() | nil) :: map()
  def normalize(nil), do: @default

  def normalize(risk) when is_map(risk) do
    @default
    |> Map.merge(stringify_keys(risk))
  end

  def normalize(_risk), do: @default

  defp stringify_keys(risk) do
    Map.new(risk, fn {key, value} -> {to_string(key), value} end)
  end
end
