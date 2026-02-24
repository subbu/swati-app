defmodule SwatiWeb.WhatsAppTemplatesLive.IndexTest do
  use SwatiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Swati.Channels

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

        {:get, "https://graph.facebook.com/v21.0/waba-123/message_templates"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "data" => [
                 %{
                   "id" => "tmpl_live",
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
             body: %{"id" => "tmpl_new", "name" => "shipping_notice", "status" => "PENDING"}
           }}

        {:post, "https://graph.facebook.com/v21.0/phone-1/messages"} ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{"messages" => [%{"id" => "wamid-live"}]}
           }}

        _ ->
          {:ok, %Req.Response{status: 404, body: %{"error" => "not_found"}}}
      end
    end
  end

  setup %{conn: conn} do
    scope = Swati.AccountsFixtures.user_scope_fixture()

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

    {:ok, [_connection]} = Channels.connect_whatsapp(scope.tenant.id, "code-123")

    {:ok, conn: log_in_user(conn, scope.user)}
  end

  test "renders guided template lifecycle page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/surfaces/whatsapp/templates")

    assert has_element?(view, "#wa-template-flow")
    assert has_element?(view, "#wa-template-table")
    assert has_element?(view, "#wa-template-send-form")
    assert render(view) =~ "order_update"
  end

  test "send template flow records evidence row", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/surfaces/whatsapp/templates")

    payload = %{
      "send" => %{
        "to" => "+15550001111",
        "body_var_1" => "Alex",
        "body_var_2" => "ORD-1001"
      }
    }

    render_submit(view, "send_template", payload)

    assert render(view) =~ "Template message sent"
    assert render(view) =~ "wamid-live"
  end

  test "create template sheet submit path", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/surfaces/whatsapp/templates")

    render_click(view, "open_create_template_sheet")

    render_submit(view, "create_template", %{
      "template" => %{
        "name" => "shipping_notice",
        "language" => "en_US",
        "category" => "UTILITY",
        "body_text" => "Your shipment is on the way"
      }
    })

    assert render(view) =~ "Template created"
  end
end
