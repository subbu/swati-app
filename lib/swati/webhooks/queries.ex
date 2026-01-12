defmodule Swati.Webhooks.Queries do
  import Ecto.Query, warn: false

  alias Swati.Agents.AgentWebhook
  alias Swati.Repo
  alias Swati.Tenancy
  alias Swati.Webhooks.WebhookTag
  alias Swati.Webhooks.Webhook

  def list_webhooks(tenant_id, opts \\ []) do
    tag_id =
      opts
      |> Keyword.get(:tag_id)
      |> normalize_tag_id()

    base_query =
      Webhook
      |> Tenancy.scope(tenant_id)
      |> order_by([w], asc: w.name)
      |> preload([:tags])

    base_query
    |> maybe_filter_by_tag(tag_id)
    |> Repo.all()
  end

  def get_webhook!(tenant_id, webhook_id) do
    Webhook
    |> Tenancy.scope(tenant_id)
    |> preload([:tags])
    |> Repo.get!(webhook_id)
  end

  def list_webhooks_for_agent(tenant_id, agent_id) do
    from(w in Webhook,
      left_join: aw in AgentWebhook,
      on: aw.webhook_id == w.id and aw.agent_id == ^agent_id,
      where: w.tenant_id == ^tenant_id,
      where: w.status == :active,
      where: is_nil(aw.id) or aw.enabled == true,
      order_by: [asc: w.name]
    )
    |> Repo.all()
  end

  def attached?(webhook_id) do
    from(aw in AgentWebhook, where: aw.webhook_id == ^webhook_id)
    |> Repo.exists?()
  end

  defp maybe_filter_by_tag(query, nil), do: query

  defp maybe_filter_by_tag(query, tag_id) do
    from(w in query,
      join: wt in WebhookTag,
      on: wt.webhook_id == w.id,
      where: wt.tag_id == ^tag_id
    )
  end

  defp normalize_tag_id(nil), do: nil
  defp normalize_tag_id(""), do: nil
  defp normalize_tag_id(tag_id), do: to_string(tag_id)
end
