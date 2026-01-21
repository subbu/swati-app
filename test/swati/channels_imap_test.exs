defmodule Swati.ChannelsImapTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels

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
    assert connection.endpoint_id
    assert connection.auth_secret_id
  end
end
