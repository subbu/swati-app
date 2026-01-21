defmodule SwatiWeb.OutlookOAuthControllerTest do
  use SwatiWeb.ConnCase, async: true

  setup :register_and_log_in_user

  defmodule TestOutlookClient do
    def request(opts) do
      case Keyword.get(opts, :url) do
        "https://login.microsoftonline.com/common/oauth2/v2.0/token" ->
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

        "https://graph.microsoft.com/v1.0/me" ->
          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "mail" => "subbu@simplyguest.com",
               "displayName" => "Subbu"
             }
           }}

        _ ->
          {:ok, %Req.Response{status: 404, body: %{"error" => "not_found"}}}
      end
    end
  end

  test "callback accepts state with atom keys", %{conn: conn, scope: scope} do
    Application.put_env(:swati, :outlook_client, TestOutlookClient)
    Application.put_env(:swati, :outlook_oauth, %{client_id: "id", client_secret: "secret"})

    on_exit(fn ->
      Application.delete_env(:swati, :outlook_client)
      Application.delete_env(:swati, :outlook_oauth)
    end)

    state = Phoenix.Token.sign(SwatiWeb.Endpoint, "outlook_oauth", %{tenant_id: scope.tenant.id})

    conn =
      get(conn, ~p"/channels/outlook/callback", %{
        "code" => "code-123",
        "state" => state
      })

    flash = conn.assigns[:flash] || conn.private[:phoenix_flash] || %{}
    assert Phoenix.Flash.get(flash, :info) == "Outlook connected."
    assert redirected_to(conn) == ~p"/channels"
  end
end
