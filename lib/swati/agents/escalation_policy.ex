defmodule Swati.Agents.EscalationPolicy do
  @spec normalize(map() | nil) :: map() | nil
  def normalize(nil), do: nil

  def normalize(policy) when is_map(policy) do
    enabled = Map.get(policy, "enabled") || Map.get(policy, :enabled) || false
    note = Map.get(policy, "note") || Map.get(policy, :note) || ""

    if enabled do
      %{"enabled" => true, "note" => note}
    else
      %{"enabled" => false}
    end
  end

  def normalize(_policy), do: nil
end
