defmodule Swati.Approvals do
  import Ecto.Query, warn: false

  alias Swati.Approvals.Approval
  alias Swati.Repo
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
end
