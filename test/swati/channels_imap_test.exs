defmodule Swati.ChannelsImapTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.SMTPTransportPolicy

  defmodule SMTPClientStub do
    def send_blocking(_email, opts) do
      if pid = Process.get(:smtp_test_pid) do
        send(pid, {:smtp_opts, opts})
      end

      case Process.get(:smtp_stub_mode) do
        :fail_max_path_once ->
          if Process.get(:smtp_stub_failed_once) do
            {:ok, "queued"}
          else
            Process.put(:smtp_stub_failed_once, true)

            {:error, :retries_exceeded,
             {:network_failure, ~c"smtp.resend.com",
              {:error, {:tls_alert, {:handshake_failure, {:bad_cert, :max_path_length_reached}}}}}}
          end

        _ ->
          {:ok, "queued"}
      end
    end
  end

  test "connect_imap stores connection and secret" do
    scope = user_scope_fixture()

    params = %{
      "email_address" => "support@zoho.com",
      "display_name" => "Zoho Support",
      "provider_label" => "Zoho Mail",
      "imap_host" => "imap.zoho.com",
      "imap_port" => 993,
      "imap_ssl" => true,
      "imap_username" => "support@zoho.com",
      "imap_password" => "secret",
      "smtp_host" => "smtp.zoho.com",
      "smtp_port" => 465,
      "smtp_ssl" => true,
      "smtp_username" => "support@zoho.com",
      "smtp_password" => "secret"
    }

    {:ok, connection} = Channels.connect_imap(scope.tenant.id, params, verify?: false)

    assert connection.provider == :imap
    assert connection.metadata["provider_label"] == "Zoho Mail"
    assert is_nil(connection.metadata["smtp_transport_policy"])
    assert connection.endpoint_id
    assert connection.auth_secret_id
  end

  test "connect_imap persists smtp transport policy override" do
    scope = user_scope_fixture()

    params = %{
      "email_address" => "support@swati.ai",
      "display_name" => "Swati Support",
      "provider_label" => "Resend SMTP",
      "imap_host" => "smtp.resend.com",
      "imap_port" => 993,
      "imap_ssl" => true,
      "imap_username" => "resend",
      "imap_password" => "secret",
      "smtp_host" => "smtp.resend.com",
      "smtp_port" => 465,
      "smtp_ssl" => true,
      "smtp_username" => "resend",
      "smtp_password" => "secret",
      "smtp_transport_mode" => "strict"
    }

    {:ok, connection} = Channels.connect_imap(scope.tenant.id, params, verify?: false)

    assert connection.metadata["smtp_transport_policy"]["mode"] == "strict"
  end

  test "send_message passes TLS options for implicit SSL SMTP connections" do
    scope = user_scope_fixture()
    Process.put(:smtp_test_pid, self())
    original_smtp_client = Application.get_env(:swati, :smtp_client)
    Application.put_env(:swati, :smtp_client, SMTPClientStub)

    on_exit(fn ->
      Process.delete(:smtp_test_pid)
      Application.put_env(:swati, :smtp_client, original_smtp_client)
    end)

    params = %{
      "email_address" => "support@zoho.com",
      "display_name" => "Zoho Support",
      "provider_label" => "Zoho Mail",
      "imap_host" => "imap.zoho.com",
      "imap_port" => 993,
      "imap_ssl" => true,
      "imap_username" => "support@zoho.com",
      "imap_password" => "secret",
      "smtp_host" => "smtp.zoho.com",
      "smtp_port" => 465,
      "smtp_ssl" => true,
      "smtp_username" => "support@zoho.com",
      "smtp_password" => "secret"
    }

    {:ok, connection} = Channels.connect_imap(scope.tenant.id, params, verify?: false)

    assert {:ok, _} =
             Channels.send_message(connection, %{
               "to" => "customer@example.com",
               "subject" => "hello",
               "text" => "world"
             })

    assert_received {:smtp_opts, opts}

    assert Keyword.get(opts, :ssl) == true
    assert Keyword.keyword?(Keyword.get(opts, :sockopts, []))
    assert Keyword.get(opts, :sockopts, []) |> Keyword.has_key?(:verify)
  end

  test "send_message falls back to verify_none on TLS path length failures" do
    scope = user_scope_fixture()
    Process.put(:smtp_test_pid, self())
    Process.put(:smtp_stub_mode, :fail_max_path_once)
    original_smtp_client = Application.get_env(:swati, :smtp_client)
    Application.put_env(:swati, :smtp_client, SMTPClientStub)

    on_exit(fn ->
      Process.delete(:smtp_test_pid)
      Process.delete(:smtp_stub_mode)
      Process.delete(:smtp_stub_failed_once)
      Application.put_env(:swati, :smtp_client, original_smtp_client)
    end)

    params = %{
      "email_address" => "support@swati.ai",
      "display_name" => "Swati Support",
      "provider_label" => "Resend SMTP",
      "imap_host" => "smtp.resend.com",
      "imap_port" => 993,
      "imap_ssl" => true,
      "imap_username" => "resend",
      "imap_password" => "secret",
      "smtp_host" => "smtp.resend.com",
      "smtp_port" => 465,
      "smtp_ssl" => true,
      "smtp_username" => "resend",
      "smtp_password" => "secret"
    }

    {:ok, connection} = Channels.connect_imap(scope.tenant.id, params, verify?: false)
    plan = SMTPTransportPolicy.plan(connection, %{host: params["smtp_host"]})
    assert plan.mode == :compatible

    assert {:ok, _} =
             Channels.send_message(connection, %{
               "to" => "customer@example.com",
               "subject" => "hello",
               "text" => "world"
             })

    assert_received {:smtp_opts, first_opts}
    assert_received {:smtp_opts, second_opts}
    assert Keyword.get(Keyword.get(first_opts, :sockopts, []), :verify) == :verify_peer
    assert Keyword.get(Keyword.get(second_opts, :sockopts, []), :verify) == :verify_none
  end
end
