defmodule Swati.Webhooks.Management do
  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Webhooks.Attrs
  alias Swati.Webhooks.Queries
  alias Swati.Webhooks.Secrets
  alias Swati.Webhooks.Tags
  alias Swati.Webhooks.Webhook

  def create_webhook(tenant_id, attrs, actor) do
    with {:ok, attrs} <- Attrs.normalize(attrs) do
      auth_token = Map.get(attrs, "auth_token")
      tag_ids = Tags.normalize_tag_ids(attrs)

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:secret, fn repo, _ ->
          Secrets.upsert(repo, tenant_id, attrs, auth_token)
        end)
        |> Ecto.Multi.run(:tags, fn repo, _ ->
          {:ok, Tags.list_by_ids(repo, tenant_id, tag_ids)}
        end)
        |> Ecto.Multi.insert(:webhook, fn %{secret: secret, tags: tags} ->
          webhook_attrs =
            attrs
            |> Map.drop(["auth_token"])
            |> Map.put("tenant_id", tenant_id)
            |> Secrets.put_secret_id(secret)

          %Webhook{}
          |> Webhook.changeset(webhook_attrs)
          |> Ecto.Changeset.put_assoc(:tags, tags)
        end)
        |> Ecto.Multi.run(:audit, fn _repo, %{webhook: webhook} ->
          Audit.log(
            tenant_id,
            actor.id,
            "webhook.create",
            "webhook",
            webhook.id,
            attrs,
            %{}
          )

          {:ok, :logged}
        end)

      case Repo.transaction(multi) do
        {:ok, %{webhook: webhook}} -> {:ok, Repo.preload(webhook, :tags)}
        {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  def update_webhook(%Webhook{} = webhook, attrs, actor) do
    with {:ok, attrs} <- Attrs.normalize(attrs),
         :ok <- ensure_tool_name_mutable(webhook, attrs) do
      auth_token = Map.get(attrs, "auth_token")
      tag_ids = tag_ids_from_attrs(attrs)
      webhook = Repo.preload(webhook, :tags)

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:secret, fn repo, _ ->
          Secrets.upsert(repo, webhook.tenant_id, attrs, auth_token, webhook)
        end)
        |> Ecto.Multi.run(:tags, fn repo, _ ->
          {:ok, tags_for(repo, webhook, tag_ids)}
        end)
        |> Ecto.Multi.update(:webhook, fn %{secret: secret, tags: tags} ->
          webhook_attrs =
            attrs
            |> Map.drop(["auth_token"])
            |> Secrets.put_secret_id(secret)

          webhook
          |> Webhook.changeset(webhook_attrs)
          |> Ecto.Changeset.put_assoc(:tags, tags)
        end)
        |> Ecto.Multi.run(:audit, fn _repo, %{webhook: webhook} ->
          Audit.log(
            webhook.tenant_id,
            actor.id,
            "webhook.update",
            "webhook",
            webhook.id,
            attrs,
            %{}
          )

          {:ok, :logged}
        end)

      case Repo.transaction(multi) do
        {:ok, %{webhook: webhook}} -> {:ok, Repo.preload(webhook, :tags)}
        {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  def delete_webhook(%Webhook{} = webhook, actor) do
    case Repo.delete(webhook) do
      {:ok, webhook} ->
        Audit.log(
          webhook.tenant_id,
          actor.id,
          "webhook.delete",
          "webhook",
          webhook.id,
          %{},
          %{}
        )

        {:ok, webhook}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp ensure_tool_name_mutable(webhook, attrs) do
    next_tool = Map.get(attrs, "tool_name") || webhook.tool_name

    if next_tool != webhook.tool_name and Queries.attached?(webhook.id) do
      {:error, "tool_name_locked"}
    else
      :ok
    end
  end

  defp tag_ids_from_attrs(attrs) do
    if Map.has_key?(attrs, "tag_ids") or Map.has_key?(attrs, :tag_ids) do
      Tags.normalize_tag_ids(attrs)
    else
      :keep
    end
  end

  defp tags_for(_repo, webhook, :keep), do: webhook.tags
  defp tags_for(repo, webhook, tag_ids), do: Tags.list_by_ids(repo, webhook.tenant_id, tag_ids)
end
