defmodule Swati.ChannelsWhatsAppTest do
  use Swati.DataCase, async: false

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.WhatsApp.TemplateMessages

  defmodule TestWhatsAppClient do
    def request(opts) do
      case {Keyword.get(opts, :method), Keyword.get(opts, :url)} do
        {:get, "https://graph.facebook.com/v21.0/oauth/access_token"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{"access_token" => "token-123", "expires_in" => 3600}
           }}

        {:get, "https://graph.facebook.com/v21.0/debug_token"} ->
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

        {:get, "https://graph.facebook.com/v21.0/waba-123/phone_numbers"} ->
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

        {:post, "https://graph.facebook.com/v21.0/waba-123/subscribed_apps"} ->
          {:ok, %Req.Response{status: 200, body: %{"success" => true}}}

        {:get, "https://graph.facebook.com/v21.0/waba-123/message_templates"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "data" => [
                 %{
                   "id" => "tmpl_approved",
                   "name" => "order_update",
                   "language" => "en_US",
                   "status" => "APPROVED",
                   "category" => "UTILITY",
                   "components" => [
                     %{"type" => "BODY", "text" => "Hi {{1}}, your order {{2}} has shipped."}
                   ]
                 }
               ]
             }
           }}

        {:post, "https://graph.facebook.com/v21.0/waba-123/message_templates"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "id" => "tmpl_new",
               "name" => "shipping_notice",
               "status" => "PENDING"
             }
           }}

        {:post, "https://graph.facebook.com/v21.0/phone-1/messages"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "messages" => [%{"id" => "wamid-123"}],
               "contacts" => [%{"input" => "15550001111"}]
             }
           }}

        {:post, "https://graph.facebook.com/v21.0/phone-2/messages"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "messages" => [%{"id" => "wamid-222"}],
               "contacts" => [%{"input" => "15550002222"}]
             }
           }}

        _ ->
          {:ok, %Req.Response{status: 404, body: %{"error" => "not_found"}}}
      end
    end
  end

  setup do
    Application.put_env(:swati, :whatsapp_client, TestWhatsAppClient)
    Application.put_env(:swati, :whatsapp, whatsapp_config())

    on_exit(fn ->
      Application.delete_env(:swati, :whatsapp_client)
      Application.delete_env(:swati, :whatsapp)
    end)

    :ok
  end

  test "connect_whatsapp creates connections for phone numbers" do
    scope = user_scope_fixture()

    {:ok, connections} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    assert length(connections) == 2
    assert Enum.all?(connections, &(&1.provider == :whatsapp))

    endpoints = Channels.list_endpoints(scope.tenant.id)
    assert Enum.any?(endpoints, &(&1.address == "+15550001111"))
    assert Enum.any?(endpoints, &(&1.address == "+15550002222"))
  end

  test "list_whatsapp_templates returns template list" do
    scope = user_scope_fixture()
    {:ok, [connection | _]} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    {:ok, templates} = Channels.list_whatsapp_templates(scope.tenant.id, connection.id)

    assert [%{"name" => "order_update", "status" => "APPROVED"}] = templates
  end

  test "create_whatsapp_template creates template via meta api" do
    scope = user_scope_fixture()
    {:ok, [connection | _]} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    {:ok, response} =
      Channels.create_whatsapp_template(scope.tenant.id, connection.id, %{
        "name" => "shipping_notice",
        "language" => "en_US",
        "category" => "UTILITY",
        "body_text" => "Order update for {{1}}"
      })

    assert response["id"] == "tmpl_new"
    assert response["status"] == "PENDING"
  end

  test "send_whatsapp_template records delivery evidence row" do
    scope = user_scope_fixture()
    {:ok, [connection | _]} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    {:ok, %{response: response, evidence: evidence}} =
      Channels.send_whatsapp_template(scope.tenant.id, connection.id, %{
        "to" => "+15550001111",
        "template" => %{
          "name" => "order_update",
          "language" => %{"code" => "en_US"},
          "components" => [
            %{
              "type" => "body",
              "parameters" => [
                %{"type" => "text", "text" => "Alex"},
                %{"type" => "text", "text" => "ORD-1001"}
              ]
            }
          ]
        }
      })

    assert get_in(response, ["messages", Access.at(0), "id"]) == "wamid-123"
    assert evidence.meta_message_id == "wamid-123"
    assert evidence.status == "sent"

    [latest] = TemplateMessages.list_recent(scope.tenant.id, connection.id, limit: 1)
    assert latest.meta_message_id == "wamid-123"
    assert latest.template_name == "order_update"
  end

  defp whatsapp_config do
    %{
      app_id: "app",
      app_secret: "secret",
      config_id: "config",
      graph_api_version: "v21.0",
      webhook_verify_token: "verify"
    }
  end
end
