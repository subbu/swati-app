defmodule SwatiWeb.Internal.HandoffsController do
  use SwatiWeb, :controller

  alias Swati.Handoffs

  def create(conn, params) do
    with {:ok, tenant_id} <- fetch_tenant_id(params),
         {:ok, handoff} <- Handoffs.request_handoff(tenant_id, params) do
      json(conn, %{handoff_id: handoff.id})
    else
      {:error, :tenant_id_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{tenant_id: ["is required"]}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  def resolve(conn, %{"id" => id} = params) do
    with {:ok, tenant_id} <- fetch_tenant_id(params),
         handoff <- Handoffs.get_handoff!(tenant_id, id),
         status when is_binary(status) <- Map.get(params, "status"),
         {:ok, handoff} <- Handoffs.resolve_handoff(handoff, status, params) do
      json(conn, %{handoff_id: handoff.id, status: handoff.status})
    else
      {:error, :tenant_id_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{tenant_id: ["is required"]}})

      nil ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{status: ["is required"]}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  defp fetch_tenant_id(params) do
    case Map.get(params, "tenant_id") || get_in(params, ["tenant", "id"]) do
      nil -> {:error, :tenant_id_required}
      tenant_id -> {:ok, tenant_id}
    end
  end

  defp render_changeset(conn, %Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
        SwatiWeb.CoreComponents.translate_error({message, opts})
      end)

    json(conn, %{error: errors})
  end
end
