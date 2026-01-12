defmodule Swati.Webhooks.Tags do
  import Ecto.Query, warn: false

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy
  alias Swati.Webhooks.Tag
  alias Swati.Webhooks.WebhookTag

  def palette do
    Tag.palette()
  end

  def palette_options do
    Tag.palette_options()
  end

  def list_tags(tenant_id) do
    Tag
    |> Tenancy.scope(tenant_id)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  def list_tags_with_counts(tenant_id) do
    from(t in Tag,
      left_join: wt in WebhookTag,
      on: wt.tag_id == t.id,
      where: t.tenant_id == ^tenant_id,
      group_by: t.id,
      order_by: [asc: t.name],
      select: %{tag: t, count: count(wt.webhook_id)}
    )
    |> Repo.all()
  end

  def list_by_ids(repo \\ Repo, tenant_id, tag_ids) do
    tag_ids = normalize_tag_ids(tag_ids)

    case tag_ids do
      [] -> []
      _ -> repo.all(from(t in Tag, where: t.tenant_id == ^tenant_id and t.id in ^tag_ids))
    end
  end

  def create_tag(tenant_id, attrs, actor) do
    attrs =
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.put("tenant_id", tenant_id)

    changeset = Tag.changeset(%Tag{}, attrs)

    case Repo.insert(changeset) do
      {:ok, tag} ->
        Audit.log(tenant_id, actor.id, "webhook.tag.create", "tag", tag.id, attrs, %{})
        {:ok, tag}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def normalize_tag_ids(attrs) when is_map(attrs) do
    attrs
    |> Map.get("tag_ids", Map.get(attrs, :tag_ids))
    |> normalize_tag_ids()
  end

  def normalize_tag_ids(tag_ids) when is_list(tag_ids) do
    tag_ids
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def normalize_tag_ids(tag_id) when is_binary(tag_id) do
    if tag_id == "", do: [], else: [tag_id]
  end

  def normalize_tag_ids(nil), do: []
  def normalize_tag_ids(_tag_ids), do: []
end
