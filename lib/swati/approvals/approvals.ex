defmodule Swati.Approvals do
  import Ecto.Query, warn: false

  alias Swati.Approvals.Approval
  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Tenancy

  def list_approvals(tenant_id, filters \\ %{}) do
    Approval
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:status, filters)
    |> maybe_filter(:case_id, filters)
    |> maybe_filter(:session_id, filters)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  def get_approval!(tenant_id, approval_id) do
    Approval
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(approval_id)
  end

  def request_approval(tenant_id, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("tenant_id", tenant_id)
      |> Map.put_new("requested_at", DateTime.utc_now())

    %Approval{}
    |> Approval.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, approval} ->
        _ = maybe_emit_event(approval, "approval.requested", approval.requested_at)
        {:ok, approval}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def resolve_approval(%Approval{} = approval, status, attrs \\ %{}) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("status", status)
      |> Map.put_new("resolved_at", DateTime.utc_now())

    approval
    |> Approval.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, approval} ->
        _ = maybe_emit_event(approval, "approval.resolved", approval.resolved_at)
        {:ok, approval}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(record in query, where: field(record, ^key) == ^value)
    end
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp maybe_emit_event(%Approval{session_id: nil}, _type, _ts), do: :ok

  defp maybe_emit_event(%Approval{} = approval, type, ts) do
    payload = %{
      "approval_id" => approval.id,
      "status" => approval.status,
      "case_id" => approval.case_id,
      "requested_by_type" => approval.requested_by_type,
      "requested_by_id" => approval.requested_by_id,
      "request_payload" => approval.request_payload,
      "decision_payload" => approval.decision_payload,
      "decision_by_user_id" => approval.decision_by_user_id
    }

    event = %{
      ts: ts,
      type: type,
      source: "control",
      idempotency_key: "approval:#{approval.id}:#{approval.status}",
      payload: payload
    }

    Sessions.append_events(approval.session_id, [event])
  end
end
