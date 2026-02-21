defmodule Swati.Tenancy.TenantsFeatureConfigTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Repo
  alias Swati.Tenancy.Tenants

  test "feature_config/3 returns default when feature config is missing" do
    tenant = tenant_fixture()
    default = %{"model" => "gpt-5-mini"}

    assert Tenants.feature_config(tenant, "sessions_ai_recommendations", default) == default
  end

  test "update_feature_config/3 deep merges existing feature config" do
    tenant = tenant_fixture()

    assert {:ok, tenant} =
             Tenants.update_feature_config(tenant, "sessions_ai_recommendations", %{
               "model" => "gpt-5",
               "timeouts" => %{"llm_ms" => 20_000}
             })

    assert {:ok, tenant} =
             Tenants.update_feature_config(tenant, :sessions_ai_recommendations, %{
               "temperature" => 0.3,
               "timeouts" => %{"ui_ms" => 30_000}
             })

    assert Tenants.feature_config(tenant, "sessions_ai_recommendations", %{}) == %{
             "model" => "gpt-5",
             "temperature" => 0.3,
             "timeouts" => %{"llm_ms" => 20_000, "ui_ms" => 30_000}
           }
  end

  defp tenant_fixture do
    user_fixture()
    |> Repo.preload(:tenant)
    |> Map.fetch!(:tenant)
  end
end
