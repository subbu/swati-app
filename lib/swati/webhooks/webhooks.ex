defmodule Swati.Webhooks do
  alias Swati.Webhooks.Attrs
  alias Swati.Webhooks.Management
  alias Swati.Webhooks.Queries
  alias Swati.Webhooks.Secrets
  alias Swati.Webhooks.Tags
  alias Swati.Webhooks.Tester
  alias Swati.Webhooks.Webhook

  def normalize_attrs(attrs) do
    Attrs.normalize(attrs)
  end

  def list_webhooks(tenant_id, opts \\ []) do
    Queries.list_webhooks(tenant_id, opts)
  end

  def get_webhook!(tenant_id, webhook_id) do
    Queries.get_webhook!(tenant_id, webhook_id)
  end

  def list_webhooks_for_agent(tenant_id, agent_id) do
    Queries.list_webhooks_for_agent(tenant_id, agent_id)
  end

  def list_webhooks_with_secrets(tenant_id, agent_id \\ nil) do
    Secrets.list_webhooks_with_secrets(tenant_id, agent_id)
  end

  def attached?(webhook_id) do
    Queries.attached?(webhook_id)
  end

  def list_tags(tenant_id) do
    Tags.list_tags(tenant_id)
  end

  def list_tags_with_counts(tenant_id) do
    Tags.list_tags_with_counts(tenant_id)
  end

  def create_tag(tenant_id, attrs, actor) do
    Tags.create_tag(tenant_id, attrs, actor)
  end

  def normalize_tag_ids(attrs) do
    Tags.normalize_tag_ids(attrs)
  end

  def tag_palette do
    Tags.palette()
  end

  def tag_palette_options do
    Tags.palette_options()
  end

  def create_webhook(tenant_id, attrs, actor) do
    Management.create_webhook(tenant_id, attrs, actor)
  end

  def update_webhook(%Webhook{} = webhook, attrs, actor) do
    Management.update_webhook(webhook, attrs, actor)
  end

  def delete_webhook(%Webhook{} = webhook, actor) do
    Management.delete_webhook(webhook, actor)
  end

  def test_webhook(%Webhook{} = webhook) do
    Tester.test_webhook(webhook)
  end
end
