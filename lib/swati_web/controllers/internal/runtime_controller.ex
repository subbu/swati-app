defmodule SwatiWeb.Internal.RuntimeController do
  use SwatiWeb, :controller

  alias Swati.Runtime
  alias SwatiWeb.Internal.RuntimeError

  def resolve(conn, params) do
    case Runtime.resolve_runtime(params) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, reason} ->
        {status, error} = RuntimeError.to_response(reason)

        conn
        |> put_status(status)
        |> json(%{error: error})
    end
  end
end
