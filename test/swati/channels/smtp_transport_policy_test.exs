defmodule Swati.Channels.SMTPTransportPolicyTest do
  use ExUnit.Case, async: true

  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.SMTPTransportPolicy

  test "uses provider profile for resend across tenants" do
    connection = %ChannelConnection{provider: :imap, metadata: %{}}
    smtp = %{host: "smtp.resend.com"}

    plan = SMTPTransportPolicy.plan(connection, smtp)

    assert plan.mode == :compatible
    assert plan.attempt_modes == [:verify_peer, :verify_none]
    assert "max_path_length_reached" in plan.fallback_error_patterns
  end

  test "metadata policy override takes precedence over provider profile" do
    connection = %ChannelConnection{
      provider: :imap,
      metadata: %{"smtp_transport_policy" => %{"mode" => "strict"}}
    }

    smtp = %{host: "smtp.resend.com"}
    plan = SMTPTransportPolicy.plan(connection, smtp)

    assert plan.mode == :strict
    assert plan.attempt_modes == [:verify_peer]
  end

  test "fallback is allowed only for matching configured errors" do
    plan = %{
      mode: :compatible,
      attempt_modes: [:verify_peer, :verify_none],
      fallback_error_patterns: ["max_path_length_reached"]
    }

    matching_error =
      {:error, :retries_exceeded,
       {:network_failure, ~c"smtp.resend.com",
        {:error, {:tls_alert, {:handshake_failure, {:bad_cert, :max_path_length_reached}}}}}}

    non_matching_error =
      {:error, :retries_exceeded, {:network_failure, ~c"mail.example.com", :closed}}

    assert SMTPTransportPolicy.allow_fallback?(plan, :verify_peer, matching_error)
    refute SMTPTransportPolicy.allow_fallback?(plan, :verify_peer, non_matching_error)
    refute SMTPTransportPolicy.allow_fallback?(plan, :verify_none, matching_error)
  end
end
