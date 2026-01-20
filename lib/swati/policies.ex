defmodule Swati.Policies do
  @spec normalize(map() | nil) :: map()
  def normalize(nil), do: %{}
  def normalize(policy) when is_map(policy), do: policy
  def normalize(_), do: %{}

  @spec merge(list(map())) :: map()
  def merge(policies) when is_list(policies) do
    Enum.reduce(policies, %{}, fn policy, acc -> deep_merge(acc, policy) end)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      deep_merge(left_value, right_value)
    end)
  end

  defp deep_merge(_left, right), do: right
end
