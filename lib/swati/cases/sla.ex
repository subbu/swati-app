defmodule Swati.Cases.Sla do
  alias Swati.Policies

  @default_policy %{
    "default_hours" => 24,
    "priorities" => %{
      "urgent" => 2,
      "high" => 6,
      "normal" => 24,
      "low" => 72
    }
  }

  @spec policy_from(list(map() | nil)) :: map()
  def policy_from(policies) when is_list(policies) do
    policies
    |> Enum.map(&sla_policy/1)
    |> then(fn overrides -> Policies.merge([@default_policy | overrides]) end)
  end

  @spec due_at(DateTime.t() | nil, atom() | binary() | nil, list(map() | nil)) ::
          DateTime.t() | nil
  def due_at(nil, _priority, _policies), do: nil

  def due_at(%DateTime{} = opened_at, priority, policies) do
    policy = policy_from(policies)
    priority_key = priority |> to_string() |> String.downcase()

    hours =
      get_in(policy, ["priorities", priority_key]) ||
        Map.get(policy, "default_hours")

    hours = normalize_integer(hours)

    if hours && hours > 0 do
      DateTime.add(opened_at, hours * 3600, :second)
    else
      nil
    end
  end

  defp sla_policy(policy) when is_map(policy) do
    policy = Policies.normalize(policy)

    case_sla =
      Map.get(policy, "case_sla") ||
        Map.get(policy, :case_sla) ||
        Map.get(policy, "sla") ||
        Map.get(policy, :sla) || %{}

    stringify_keys_deep(case_sla)
  end

  defp sla_policy(_policy), do: %{}

  defp stringify_keys_deep(nil), do: %{}

  defp stringify_keys_deep(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify_keys_deep(value)} end)
  end

  defp stringify_keys_deep(list) when is_list(list) do
    Enum.map(list, &stringify_keys_deep/1)
  end

  defp stringify_keys_deep(value), do: value

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} -> parsed
      :error -> nil
    end
  end

  defp normalize_integer(_), do: nil
end
