defmodule Swati.Agents.ToolPolicy do
  alias Swati.Integrations.ToolAllowlist

  @spec default() :: map()
  def default do
    %{
      "allow" => [],
      "deny" => [],
      "max_calls_per_turn" => 3
    }
  end

  @spec normalize(map() | nil) :: map()
  def normalize(nil), do: default()

  def normalize(policy) when is_map(policy) do
    %{
      "allow" => list_value(policy, "allow"),
      "deny" => list_value(policy, "deny"),
      "max_calls_per_turn" => integer_value(policy, "max_calls_per_turn", 3)
    }
  end

  def normalize(_policy), do: default()

  @spec effective(map() | nil, list({term(), term()})) :: map()
  def effective(base_config, integrations) do
    base_policy = normalize(Map.get(base_config || %{}, "tool_policy"))
    base_allow = Map.get(base_policy, "allow", [])
    base_deny = Map.get(base_policy, "deny", [])
    base_max_calls = Map.get(base_policy, "max_calls_per_turn", 3)

    integration_allow =
      integrations
      |> Enum.flat_map(fn {integration, _secret} ->
        ToolAllowlist.allowed_tools(integration)
      end)
      |> Enum.uniq()

    allow =
      cond do
        base_allow != [] and integration_allow != [] ->
          Enum.filter(base_allow, &(&1 in integration_allow))

        base_allow != [] ->
          base_allow

        integration_allow != [] ->
          integration_allow

        true ->
          []
      end

    allow =
      if base_deny == [] or allow == [] do
        allow
      else
        Enum.reject(allow, &(&1 in base_deny))
      end

    %{
      "allow" => allow,
      "deny" => base_deny,
      "max_calls_per_turn" => base_max_calls
    }
  end

  defp list_value(policy, key) when is_map(policy) do
    value = Map.get(policy, key) || Map.get(policy, String.to_atom(key))
    if is_list(value), do: value, else: []
  end

  defp list_value(_policy, _key), do: []

  defp integer_value(policy, key, default) when is_map(policy) do
    value = Map.get(policy, key) || Map.get(policy, String.to_atom(key))
    if is_integer(value), do: value, else: default
  end

  defp integer_value(_policy, _key, default), do: default
end
