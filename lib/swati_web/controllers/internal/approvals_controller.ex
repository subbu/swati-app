defmodule SwatiWeb.Internal.ApprovalsController do
  use SwatiWeb, :controller

  alias Swati.Approvals

  def create(conn, params) do
    with {:ok, tenant_id} <- fetch_tenant_id(params),
         {:ok, approval} <- Approvals.request_approval(tenant_id, params) do
      json(conn, %{approval_id: approval.id})
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
         approval <- Approvals.get_approval!(tenant_id, id),
         status when is_binary(status) <- Map.get(params, "status"),
         {:ok, approval} <- Approvals.resolve_approval(approval, status, params) do
      json(conn, %{approval_id: approval.id, status: approval.status})
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
