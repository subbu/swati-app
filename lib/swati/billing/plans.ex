defmodule Swati.Billing.Plans do
  alias Swati.Billing.Queries

  def get_by_code(code) when is_binary(code) do
    Queries.get_plan_by_code(code)
  end

  def get_by_provider_plan_id(provider, provider_plan_id)
      when is_binary(provider) and is_binary(provider_plan_id) do
    Queries.get_plan_by_provider_plan_id(provider, provider_plan_id)
  end

  def get_provider_plan_id(plan_code, provider)
      when is_binary(plan_code) and is_binary(provider) do
    Queries.get_provider_plan_id(plan_code, provider)
  end

  def list_active_plans do
    Queries.list_active_plans()
  end

  def default_plan do
    get_by_code("starter")
  end
end
