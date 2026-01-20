defmodule Swati.Cases.Commands do
  alias Swati.Cases.Case
  alias Swati.Cases.CaseStatusTransitions
  alias Swati.Cases.Sla
  alias Swati.Repo
  alias Swati.Tenancy

  def create_case(tenant_id, attrs) do
    attrs = stringify_keys(attrs)
    opened_at = Map.get(attrs, "opened_at")
    tenant = Tenancy.get_tenant!(tenant_id)

    attrs =
      attrs
      |> Map.put("tenant_id", tenant_id)
      |> maybe_put_opened_at(opened_at)
      |> maybe_put_sla_due_at(tenant.policy)
      |> normalize_status()

    %Case{}
    |> Case.changeset(attrs)
    |> Repo.insert()
  end

  def update_case(%Case{} = case_record, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> normalize_status()

    case_record
    |> Case.changeset(attrs)
    |> Repo.update()
  end

  def set_case_status(%Case{} = case_record, status) do
    status = CaseStatusTransitions.normalize_status(status)
    update_case(case_record, %{status: status})
  end

  defp normalize_status(attrs) do
    status = Map.get(attrs, "status")

    if is_nil(status) do
      attrs
    else
      Map.put(attrs, "status", CaseStatusTransitions.normalize_status(status))
    end
  end

  defp maybe_put_opened_at(attrs, nil) do
    Map.put(attrs, "opened_at", DateTime.utc_now())
  end

  defp maybe_put_opened_at(attrs, opened_at), do: Map.put(attrs, "opened_at", opened_at)

  defp maybe_put_sla_due_at(attrs, tenant_policy) do
    if Map.get(attrs, "sla_due_at") do
      attrs
    else
      opened_at = Map.get(attrs, "opened_at")
      priority = Map.get(attrs, "priority") || :normal
      case_policy = Map.get(attrs, "policy") || %{}

      case Sla.due_at(opened_at, priority, [tenant_policy, case_policy]) do
        %DateTime{} = due_at -> Map.put(attrs, "sla_due_at", due_at)
        _ -> attrs
      end
    end
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
