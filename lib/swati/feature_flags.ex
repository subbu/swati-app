defmodule Swati.FeatureFlags do
  alias Swati.Tenancy.Tenant

  @sessions_ai_recommendations :sessions_ai_recommendations

  def sessions_ai_recommendations?(%Tenant{} = tenant) do
    FunWithFlags.enabled?(@sessions_ai_recommendations, for: tenant)
  end

  def enable_sessions_ai_recommendations(%Tenant{} = tenant) do
    FunWithFlags.enable(@sessions_ai_recommendations, for_actor: tenant)
  end

  def disable_sessions_ai_recommendations(%Tenant{} = tenant) do
    FunWithFlags.disable(@sessions_ai_recommendations, for_actor: tenant)
  end

  def sessions_ai_recommendations_flag, do: @sessions_ai_recommendations
end
