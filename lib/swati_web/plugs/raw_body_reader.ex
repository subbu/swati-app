defmodule SwatiWeb.Plugs.RawBodyReader do
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}

      {:more, body, conn} ->
        {:more, body, Plug.Conn.assign(conn, :raw_body, body)}

      {:error, _} = error ->
        error
    end
  end
end
