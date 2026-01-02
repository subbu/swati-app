defmodule SwatiWeb.Plugs.VerifyInternalToken do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    token = Application.get_env(:swati, :internal_api_token)

    with ["Bearer " <> provided] <- get_req_header(conn, "authorization"),
         true <- is_binary(token),
         true <- Plug.Crypto.secure_compare(provided, token) do
      conn
    else
      _ ->
        conn
        |> send_resp(401, "")
        |> halt()
    end
  end
end
