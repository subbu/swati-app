defmodule Swati.Features.SessionsAiRecommendationsTest do
  use ExUnit.Case, async: true

  alias Swati.Features.SessionsAiRecommendations
  alias Swati.Tenancy.Tenant

  test "config/1 normalizes tenant feature config values" do
    tenant = %Tenant{
      id: 123,
      policy: %{
        "feature_configs" => %{
          "sessions_ai_recommendations" => %{
            "model" => "  gpt-5  ",
            "temperature" => "4.2",
            "timeout_ms" => "1000"
          }
        }
      }
    }

    assert SessionsAiRecommendations.config(tenant) == %{
             "model" => "gpt-5",
             "temperature" => 1.0,
             "timeout_ms" => 5_000
           }
  end

  test "config/1 falls back to defaults" do
    tenant = %Tenant{id: 123, policy: %{}}

    assert SessionsAiRecommendations.config(tenant) == SessionsAiRecommendations.defaults()
  end
end
