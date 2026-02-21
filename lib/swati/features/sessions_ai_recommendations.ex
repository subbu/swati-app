defmodule Swati.Features.SessionsAiRecommendations do
  alias Swati.FeatureFlags
  alias Swati.Tenancy.Tenant
  alias Swati.Tenancy.Tenants

  @feature_key "sessions_ai_recommendations"
  @default_model "gpt-5-mini"
  @default_temperature 0.2
  @default_timeout_ms 20_000
  @default_prompt "Recommend 2 concrete next actions for these selected conversations."

  def feature_key, do: @feature_key

  def enabled?(%Tenant{} = tenant), do: FeatureFlags.sessions_ai_recommendations?(tenant)

  def default_prompt, do: @default_prompt

  def defaults do
    %{
      "model" => @default_model,
      "temperature" => @default_temperature,
      "timeout_ms" => @default_timeout_ms
    }
  end

  def config(%Tenant{} = tenant) do
    tenant
    |> Tenants.feature_config(@feature_key, %{})
    |> normalize_config()
  end

  def recommendation_opts(%Tenant{} = tenant) do
    feature_config = config(tenant)

    [
      model: feature_config["model"],
      temperature: feature_config["temperature"]
    ]
  end

  def timeout_ms(%Tenant{} = tenant), do: config(tenant)["timeout_ms"]

  defp normalize_config(config) when is_map(config) do
    defaults()
    |> Map.merge(config)
    |> Map.update!("model", &normalize_model/1)
    |> Map.update!("temperature", &normalize_temperature/1)
    |> Map.update!("timeout_ms", &normalize_timeout_ms/1)
  end

  defp normalize_config(_), do: defaults()

  defp normalize_model(value) do
    case value |> to_string() |> String.trim() do
      "" -> @default_model
      model -> String.slice(model, 0, 120)
    end
  end

  defp normalize_temperature(value) when is_number(value) do
    value
    |> max(0.0)
    |> min(1.0)
  end

  defp normalize_temperature(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, ""} -> normalize_temperature(parsed)
      _ -> @default_temperature
    end
  end

  defp normalize_temperature(_), do: @default_temperature

  defp normalize_timeout_ms(value) when is_integer(value) do
    value
    |> max(5_000)
    |> min(120_000)
  end

  defp normalize_timeout_ms(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> normalize_timeout_ms(parsed)
      _ -> @default_timeout_ms
    end
  end

  defp normalize_timeout_ms(_), do: @default_timeout_ms
end
