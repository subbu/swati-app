defmodule Swati.Billing.Entitlements do
  alias Swati.Billing.Plans
  alias Swati.Tenancy.Tenant

  def effective(%Tenant{} = tenant) do
    plan = Plans.get_by_code(tenant.plan) || Plans.default_plan()
    plan_entitlements = (plan && plan.entitlements) || %{}
    overrides = tenant.policy |> Map.get("billing_overrides", %{})

    plan_entitlements
    |> Map.merge(overrides, fn _key, _left, right -> right end)
    |> normalize()
  end

  def max_phone_numbers(entitlements) do
    entitlements |> Map.get("max_phone_numbers") |> parse_int()
  end

  def max_integrations(entitlements) do
    entitlements |> Map.get("max_integrations") |> parse_int()
  end

  def included_call_minutes(entitlements) do
    entitlements |> Map.get("included_call_minutes") |> parse_int()
  end

  def normalize_entitlements(entitlements) when is_map(entitlements) do
    normalize(entitlements)
  end

  defp normalize(entitlements) when is_map(entitlements) do
    entitlements
    |> Enum.map(fn {key, value} -> {key, normalize_value(value)} end)
    |> Map.new()
  end

  defp normalize_value(value) when is_integer(value), do: value
  defp normalize_value(value) when is_binary(value), do: parse_int(value) || value
  defp normalize_value(value), do: value

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      _ -> nil
    end
  end
end
