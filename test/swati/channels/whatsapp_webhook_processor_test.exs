defmodule Swati.Channels.WhatsAppWebhookProcessorTest do
  use Swati.DataCase, async: false

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.WhatsApp.TemplateMessages
  alias Swati.Channels.WhatsApp.WebhookProcessor

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
                 }
               ]
             }
           }}

        {:post, "https://graph.facebook.com/v21.0/waba-123/subscribed_apps"} ->
          {:ok, %Req.Response{status: 200, body: %{"success" => true}}}

        {:post, "https://graph.facebook.com/v21.0/phone-1/messages"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{"messages" => [%{"id" => "wamid-123"}]}
           }}

        _ ->
          {:ok, %Req.Response{status: 404, body: %{"error" => "not_found"}}}
      end
    end
  end

  setup do
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

    :ok
  end

  test "status webhook updates existing template evidence" do
    scope = user_scope_fixture()
    {:ok, [connection]} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    {:ok, _} =
      Channels.send_whatsapp_template(scope.tenant.id, connection.id, %{
        "to" => "+15550001111",
        "template" => %{
          "name" => "order_update",
          "language" => %{"code" => "en_US"}
        }
      })

    payload = %{
      "entry" => [
        %{
          "changes" => [
            %{
              "field" => "messages",
              "value" => %{
                "metadata" => %{
                  "phone_number_id" => "phone-1",
                  "display_phone_number" => "+1 555 000 1111"
                },
                "statuses" => [
                  %{
                    "id" => "wamid-123",
                    "status" => "delivered",
                    "recipient_id" => "15550001111",
                    "timestamp" => "1735718400"
                  }
                ]
              }
            }
          ]
        }
      ]
    }

    assert :ok = WebhookProcessor.handle_webhook(payload)

    message = TemplateMessages.get_by_meta_message_id(scope.tenant.id, "wamid-123")
    assert message.status == "delivered"
    assert not is_nil(message.delivered_at)
    assert get_in(message.status_events, ["events", Access.at(-1), "status"]) == "delivered"
  end

  test "status webhook creates evidence row when message id is unknown" do
    scope = user_scope_fixture()
    {:ok, [_connection]} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    payload = %{
      "entry" => [
        %{
          "changes" => [
            %{
              "field" => "messages",
              "value" => %{
                "metadata" => %{"phone_number_id" => "phone-1"},
                "statuses" => [
                  %{
                    "id" => "wamid-999",
                    "status" => "read",
                    "recipient_id" => "15550001111",
                    "timestamp" => "1735718400"
                  }
                ]
              }
            }
          ]
        }
      ]
    }

    assert :ok = WebhookProcessor.handle_webhook(payload)

    message = TemplateMessages.get_by_meta_message_id(scope.tenant.id, "wamid-999")
    assert message.status == "read"
    assert message.template_name == "unknown_template"
    assert not is_nil(message.read_at)
  end
end
