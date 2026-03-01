defmodule Swati.Channels.SMTPTransportPolicy do
  @moduledoc false

  alias Swati.Channels.ChannelConnection

  @default_mode :strict
  @default_fallback_patterns ["max_path_length_reached"]

  @type mode :: :strict | :compatible | :insecure
  @type plan :: %{
          mode: mode(),
          attempt_modes: [atom()],
          fallback_error_patterns: [String.t()]
        }

  @spec plan(ChannelConnection.t() | map() | nil, map()) :: plan()
  def plan(connection, smtp) when is_map(smtp) do
    mode = resolve_mode(connection, smtp)
    patterns = resolve_fallback_error_patterns(connection, smtp)

    %{
      mode: mode,
      attempt_modes: attempt_modes(mode),
      fallback_error_patterns: patterns
    }
  end

  @spec allow_fallback?(plan(), atom(), term()) :: boolean()
  def allow_fallback?(plan, verify_mode, error) when is_map(plan) do
    verify_mode == :verify_peer and
      plan[:attempt_modes] |> List.wrap() |> Enum.member?(:verify_none) and
      matches_error_patterns?(error, plan[:fallback_error_patterns] || @default_fallback_patterns)
  end

  @spec resolve_mode(ChannelConnection.t() | map() | nil, map()) :: mode()
  def resolve_mode(connection, smtp) do
    with nil <- metadata_mode(connection),
         nil <- provider_profile_mode(connection, smtp) do
      normalize_mode(Map.get(config(), :default_mode, @default_mode))
    end
  end

  @spec resolve_fallback_error_patterns(ChannelConnection.t() | map() | nil, map()) :: [
          String.t()
        ]
  def resolve_fallback_error_patterns(connection, smtp) do
    cond do
      patterns = metadata_fallback_patterns(connection) ->
        patterns

      patterns = provider_profile_fallback_patterns(connection, smtp) ->
        patterns

      true ->
        normalize_patterns(Map.get(config(), :default_fallback_error_patterns, []))
    end
    |> case do
      [] -> @default_fallback_patterns
      patterns -> patterns
    end
  end

  defp attempt_modes(:strict), do: [:verify_peer]
  defp attempt_modes(:compatible), do: [:verify_peer, :verify_none]
  defp attempt_modes(:insecure), do: [:verify_none]

  defp metadata_mode(connection) do
    connection
    |> metadata_policy()
    |> Map.get("mode")
    |> normalize_mode_or_nil()
  end

  defp metadata_fallback_patterns(connection) do
    connection
    |> metadata_policy()
    |> Map.get("fallback_error_patterns")
    |> normalize_patterns()
    |> case do
      [] -> nil
      patterns -> patterns
    end
  end

  defp metadata_policy(nil), do: %{}

  defp metadata_policy(connection) do
    metadata = Map.get(connection, :metadata) || Map.get(connection, "metadata") || %{}

    policy =
      Map.get(metadata, "smtp_transport_policy") || Map.get(metadata, :smtp_transport_policy)

    case policy do
      policy when is_map(policy) ->
        policy
        |> Map.new(fn
          {key, value} when is_atom(key) -> {Atom.to_string(key), value}
          {key, value} -> {to_string(key), value}
        end)

      policy when is_binary(policy) ->
        %{"mode" => policy}

      policy when is_atom(policy) ->
        %{"mode" => Atom.to_string(policy)}

      _ ->
        %{}
    end
  end

  defp provider_profile_mode(connection, smtp) do
    connection
    |> matching_profile(smtp)
    |> case do
      nil -> nil
      profile -> normalize_mode_or_nil(Map.get(profile, :mode) || Map.get(profile, "mode"))
    end
  end

  defp provider_profile_fallback_patterns(connection, smtp) do
    connection
    |> matching_profile(smtp)
    |> case do
      nil ->
        nil

      profile ->
        profile
        |> Map.get(:fallback_error_patterns, Map.get(profile, "fallback_error_patterns"))
        |> normalize_patterns()
        |> case do
          [] -> nil
          patterns -> patterns
        end
    end
  end

  defp matching_profile(connection, smtp) do
    host =
      smtp
      |> Map.get(:host, Map.get(smtp, "host"))
      |> normalize_host()

    provider =
      connection
      |> case do
        nil -> nil
        _ -> Map.get(connection, :provider) || Map.get(connection, "provider")
      end
      |> normalize_provider()

    config()
    |> Map.get(:provider_profiles, [])
    |> Enum.map(&normalize_profile/1)
    |> Enum.find(fn profile ->
      profile_matches_provider?(profile, provider) and profile_matches_host?(profile, host)
    end)
  end

  defp normalize_profile(profile) when is_map(profile) do
    %{
      provider:
        Map.get(profile, :provider) ||
          Map.get(profile, "provider")
          |> normalize_provider(),
      host: Map.get(profile, :host) || Map.get(profile, "host") |> normalize_host(),
      host_suffix:
        Map.get(profile, :host_suffix) || Map.get(profile, "host_suffix") |> normalize_host(),
      mode: Map.get(profile, :mode) || Map.get(profile, "mode"),
      fallback_error_patterns:
        Map.get(profile, :fallback_error_patterns) || Map.get(profile, "fallback_error_patterns")
    }
  end

  defp normalize_profile(_), do: %{}

  defp profile_matches_provider?(profile, provider) do
    case profile[:provider] do
      nil -> true
      expected -> expected == provider
    end
  end

  defp profile_matches_host?(profile, host) do
    cond do
      host in [nil, ""] ->
        false

      profile[:host] not in [nil, ""] ->
        profile[:host] == host

      profile[:host_suffix] not in [nil, ""] ->
        String.ends_with?(host, profile[:host_suffix])

      true ->
        true
    end
  end

  defp matches_error_patterns?(error, patterns) do
    text =
      error
      |> inspect(limit: :infinity)
      |> String.downcase()

    Enum.any?(patterns, fn pattern ->
      normalized = pattern |> to_string() |> String.downcase()
      normalized != "" and String.contains?(text, normalized)
    end)
  end

  defp config do
    case Application.get_env(:swati, :smtp_transport_policy, %{}) do
      config when is_map(config) -> config
      config when is_list(config) -> Map.new(config)
      _ -> %{}
    end
  end

  defp normalize_provider(nil), do: nil
  defp normalize_provider(value) when is_atom(value), do: value

  defp normalize_provider(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      "" ->
        nil

      provider ->
        try do
          String.to_existing_atom(provider)
        rescue
          _ -> nil
        end
    end
  end

  defp normalize_provider(_), do: nil

  defp normalize_host(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      host -> host
    end
  end

  defp normalize_host(_), do: nil

  defp normalize_mode(value) do
    case normalize_mode_or_nil(value) do
      nil -> @default_mode
      mode -> mode
    end
  end

  defp normalize_mode_or_nil(value) when value in [:strict, :compatible, :insecure], do: value

  defp normalize_mode_or_nil(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "strict" -> :strict
      "compatible" -> :compatible
      "insecure" -> :insecure
      _ -> nil
    end
  end

  defp normalize_mode_or_nil(_), do: nil

  defp normalize_patterns(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_patterns(value) when is_binary(value), do: normalize_patterns([value])
  defp normalize_patterns(_), do: []
end
