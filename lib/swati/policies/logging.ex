defmodule Swati.Policies.Logging do
  alias Swati.Policies

  @default_retention_days 30

  @spec retention_days(list(map() | nil), integer()) :: integer()
  def retention_days(policies, default \\ @default_retention_days) do
    policies
    |> Enum.map(&Policies.normalize/1)
    |> Enum.reduce(default, fn policy, acc ->
      value =
        policy
        |> get_in(["logging", "retention_days"])
        |> normalize_integer()

      if value && value > 0, do: value, else: acc
    end)
  end

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} -> parsed
      :error -> nil
    end
  end

  defp normalize_integer(_value), do: nil
end
