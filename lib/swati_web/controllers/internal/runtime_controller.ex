defmodule SwatiWeb.Internal.RuntimeController do
  use SwatiWeb, :controller

  alias Swati.Runtime

  def show(conn, %{"phone_number_id" => phone_number_id}) do
    case Runtime.runtime_config_for_phone_number(phone_number_id) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, :phone_number_missing_agent} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "phone_number_missing_agent"})

      {:error, :agent_not_published} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "agent_not_published"})
    end
  end
end
