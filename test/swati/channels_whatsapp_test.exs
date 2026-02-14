defmodule Swati.ChannelsWhatsAppTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels

  defmodule TestWhatsAppClient do
    def request(opts) do
      case Keyword.get(opts, :url) do
        "https://graph.facebook.com/v21.0/oauth/access_token" ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{"access_token" => "token-123", "expires_in" => 3600}
           }}

        "https://graph.facebook.com/v21.0/debug_token" ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "data" => %{
                 "granular_scopes" => [
                   %{"scope" => "whatsapp_business_management", "target_ids" => ["waba-123"]}
                 ]
               }
             }
           }}

        "https://graph.facebook.com/v21.0/waba-123/phone_numbers" ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "data" => [
                 %{
                   "id" => "phone-1",
                   "display_phone_number" => "+1 555 000 1111",
                   "verified_name" => "Support"
                 },
                 %{
                   "id" => "phone-2",
                   "display_phone_number" => "+1 555 000 2222",
                   "verified_name" => "Sales"
                 }
               ]
             }
           }}

        "https://graph.facebook.com/v21.0/waba-123/subscribed_apps" ->
          {:ok, %Req.Response{status: 200, body: %{"success" => true}}}

        _ ->
          {:ok, %Req.Response{status: 404, body: %{"error" => "not_found"}}}
      end
    end
  end

  test "connect_whatsapp creates connections for phone numbers" do
    scope = user_scope_fixture()

    Application.put_env(:swati, :whatsapp_client, TestWhatsAppClient)

    Application.put_env(:swati, :whatsapp, %{
      app_id: "app",
      app_secret: "secret",
      config_id: "config",
      graph_api_version: "v21.0",
      webhook_verify_token: "verify"
    })

    on_exit(fn ->
      Application.delete_env(:swati, :whatsapp_client)
      Application.delete_env(:swati, :whatsapp)
    end)

    {:ok, connections} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    assert length(connections) == 2
    assert Enum.all?(connections, &(&1.provider == :whatsapp))

    endpoints = Channels.list_endpoints(scope.tenant.id)
    assert Enum.any?(endpoints, &(&1.address == "+15550001111"))
    assert Enum.any?(endpoints, &(&1.address == "+15550002222"))
  end
end
