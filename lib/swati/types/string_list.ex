defmodule Swati.Types.StringList do
  use Ecto.Type

  def type, do: :map

  def cast(nil), do: {:ok, []}

  def cast(list) when is_list(list) do
    {:ok, Enum.map(list, &to_string/1)}
  end

  def cast(value) when is_binary(value) do
    list =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:ok, list}
  end

  def cast(_), do: :error

  def load(list) when is_list(list), do: {:ok, list}
  def load(_), do: {:ok, []}

  def dump(list) when is_list(list), do: {:ok, list}
  def dump(_), do: :error
end
