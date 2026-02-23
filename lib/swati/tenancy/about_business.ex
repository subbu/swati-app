defmodule Swati.Tenancy.AboutBusiness do
  @moduledoc false
  import Ecto.Changeset

  @field_limits %{
    business_identity: 500,
    business_brand_voice: 500,
    business_operating_boundaries: 500,
    business_escalation_map: 400,
    business_top_workflows: 1200
  }

  def fields do
    Map.keys(@field_limits)
  end

  def attrs(params, tenant) when is_map(params) do
    Enum.reduce(fields(), %{}, fn field, acc ->
      key = Atom.to_string(field)

      value =
        cond do
          Map.has_key?(params, key) -> Map.get(params, key)
          Map.has_key?(params, field) -> Map.get(params, field)
          true -> Map.get(tenant, field)
        end

      Map.put(acc, field, value || "")
    end)
  end

  def validate_lengths(changeset) do
    Enum.reduce(@field_limits, changeset, fn {field, max}, acc ->
      validate_length(acc, field, max: max)
    end)
  end
end
