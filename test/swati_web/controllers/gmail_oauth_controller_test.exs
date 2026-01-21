defmodule SwatiWeb.GmailOAuthControllerTest do
  use SwatiWeb.ConnCase, async: true

  setup :register_and_log_in_user

  defmodule TestGmailClient do
    def request(opts) do
      case Keyword.get(opts, :url) do
        "https://oauth2.googleapis.com/token" ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "access_token" => "token-123",
               "expires_in" => 3600,
               "refresh_token" => "refresh-123",
               "scope" => "email profile"
             }
           }}

        "https://www.googleapis.com/oauth2/v2/userinfo" ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "email" => "subbu@simplyguest.com",
               "name" => "Subbu"
             }
           }}

        _ ->
          {:ok, %Req.Response{status: 404, body: %{"error" => "not_found"}}}
      end
    end
  end

  test "callback accepts state with atom keys", %{conn: conn, scope: scope} do
    Application.put_env(:swati, :gmail_client, TestGmailClient)
    Application.put_env(:swati, :gmail_oauth, %{client_id: "id", client_secret: "secret"})

    on_exit(fn ->
      Application.delete_env(:swati, :gmail_client)
      Application.delete_env(:swati, :gmail_oauth)
    end)

    state = Phoenix.Token.sign(SwatiWeb.Endpoint, "gmail_oauth", %{tenant_id: scope.tenant.id})

    conn =
      get(conn, ~p"/channels/gmail/callback", %{
        "code" => "code-123",
        "state" => state
      })

    flash = conn.assigns[:flash] || conn.private[:phoenix_flash] || %{}
    assert Phoenix.Flash.get(flash, :info) == "Gmail connected."
    assert redirected_to(conn) == ~p"/channels"
  end
end
