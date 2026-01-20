defmodule Swati.Policies.ToolPolicy do
  alias Swati.Agents.ToolPolicy
  alias Swati.Policies

  @spec effective(
          map() | nil,
          list({term(), term()}),
          list({term(), term()}),
          list(String.t()),
          list(map() | nil)
        ) :: map()
  def effective(base_config, integrations, webhooks, channel_tools, policy_layers) do
    base = ToolPolicy.effective(base_config, integrations, webhooks, channel_tools)
    apply_layers(base, policy_layers)
  end

  defp apply_layers(base, policy_layers) do
    policy_layers
    |> Enum.map(&layer_policy/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(base, &apply_layer/2)
  end

  defp layer_policy(policy) do
    tool_policy =
      policy
      |> Policies.normalize()
      |> Map.get("tool_policy")

    if is_map(tool_policy) do
      %{
        "allow" => list_value(tool_policy, "allow"),
        "deny" => list_value(tool_policy, "deny"),
        "max_calls_per_turn" => integer_value(tool_policy, "max_calls_per_turn")
      }
    else
      nil
    end
  end

  defp apply_layer(layer, base) do
    allow_override = Map.get(layer, "allow", :unset)
    deny_override = Map.get(layer, "deny", :unset)
    max_calls_override = Map.get(layer, "max_calls_per_turn", :unset)

    base_allow = Map.get(base, "allow", [])
    base_deny = Map.get(base, "deny", [])
    base_max = Map.get(base, "max_calls_per_turn", 3)

    allow =
      case allow_override do
        :unset -> base_allow
        [] -> []
        _allow_list when base_allow == [] -> []
        allow_list -> Enum.filter(base_allow, &(&1 in allow_list))
      end

    deny =
      case deny_override do
        :unset -> base_deny
        deny_list -> Enum.uniq(base_deny ++ deny_list)
      end

    allow =
      if allow == [] or deny == [] do
        allow
      else
        Enum.reject(allow, &(&1 in deny))
      end

    max_calls = normalize_max_calls(base_max, max_calls_override)

    %{"allow" => allow, "deny" => deny, "max_calls_per_turn" => max_calls}
  end

  defp normalize_max_calls(base_max, :unset), do: base_max
  defp normalize_max_calls(base_max, value) when is_integer(value), do: min(base_max, value)
  defp normalize_max_calls(base_max, _value), do: base_max

  defp list_value(map, key) do
    atom_key = String.to_atom(key)

    if Map.has_key?(map, key) or Map.has_key?(map, atom_key) do
      value = Map.get(map, key) || Map.get(map, atom_key)
      if is_list(value), do: value, else: []
    else
      :unset
    end
  end

  defp integer_value(map, key) do
    atom_key = String.to_atom(key)

    if Map.has_key?(map, key) or Map.has_key?(map, atom_key) do
      value = Map.get(map, key) || Map.get(map, atom_key)
      if is_integer(value), do: value, else: nil
    else
      :unset
    end
  end
end
