defmodule SwatiWeb.Internal.RuntimeController do
  use SwatiWeb, :controller

  alias Swati.Runtime

  def resolve(conn, params) do
    case Runtime.resolve_runtime(params) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, :endpoint_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "endpoint_not_found"})

      {:error, :customer_identity_missing} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "customer_identity_missing"})

      {:error, :agent_missing} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "agent_missing"})

      {:error, :agent_not_published} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "agent_not_published"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
