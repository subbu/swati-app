defmodule Swati.Avatars do
  import Ecto.Query, warn: false

  alias Swati.Agents.Agent
  alias Swati.Agents.AgentAvatar
  alias Swati.Avatars.Providers.Replicate
  alias Swati.Avatars.Storage
  alias Swati.Repo
  alias Swati.Tenancy
  alias Swati.Workers.GenerateAgentAvatar

  def topic(tenant_id), do: "avatars:#{tenant_id}"

  def subscribe(tenant_id) do
    Phoenix.PubSub.subscribe(Swati.PubSub, topic(tenant_id))
  end

  def broadcast_avatar_update(%AgentAvatar{} = avatar) do
    Phoenix.PubSub.broadcast(Swati.PubSub, topic(avatar.tenant_id), {:avatar_updated, avatar})
  end

  def request_agent_avatar(current_scope, %Agent{} = agent, opts \\ %{}) do
    attrs = build_avatar_attrs(current_scope, agent, opts)

    Repo.transaction(fn ->
      case %AgentAvatar{}
           |> AgentAvatar.changeset(attrs)
           |> Repo.insert() do
        {:ok, avatar} ->
          %{avatar_id: avatar.id}
          |> GenerateAgentAvatar.new(queue: :media)
          |> Oban.insert!()

          avatar

        {:error, %Ecto.Changeset{} = changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, avatar} ->
        broadcast_avatar_update(avatar)
        {:ok, avatar}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def get_latest_avatar(current_scope, agent_id) do
    AgentAvatar
    |> Tenancy.scope(current_scope.tenant.id)
    |> where([avatar], avatar.agent_id == ^agent_id)
    |> order_by([avatar], desc: avatar.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def latest_avatars_by_agent(current_scope, agent_ids) do
    agent_ids = Enum.uniq(agent_ids)

    if agent_ids == [] do
      %{}
    else
      AgentAvatar
      |> where([avatar], avatar.tenant_id == ^current_scope.tenant.id)
      |> where([avatar], avatar.agent_id in ^agent_ids)
      |> distinct([avatar], avatar.agent_id)
      |> order_by([avatar], asc: avatar.agent_id, desc: avatar.inserted_at)
      |> Repo.all()
      |> Map.new(fn avatar -> {avatar.agent_id, avatar} end)
    end
  end

  def delete_latest_avatar(current_scope, agent_id) do
    case get_latest_avatar(current_scope, agent_id) do
      nil -> {:error, :not_found}
      avatar -> delete_avatar(current_scope, avatar)
    end
  end

  def delete_avatar(current_scope, %AgentAvatar{} = avatar) do
    if avatar.tenant_id != current_scope.tenant.id do
      {:error, :not_found}
    else
      Repo.delete(avatar)
    end
  end

  def generate_avatar(avatar_id) do
    avatar = Repo.get!(AgentAvatar, avatar_id) |> Repo.preload(:agent)

    case avatar.status do
      :ready ->
        {:ok, avatar}

      :failed ->
        {:error, :failed}

      _status ->
        result =
          try do
            with {:ok, avatar} <-
                   update_avatar_and_broadcast(avatar, %{status: :running, error: nil}),
                 {:ok, prediction} <- fetch_or_create_prediction(avatar, avatar.agent),
                 {:ok, avatar} <- maybe_set_prediction_id(avatar, prediction.id),
                 {:ok, prediction} <- Replicate.wait(prediction),
                 {:ok, source_url} <- Replicate.first_output_url(prediction),
                 {:ok, %{public_url: public_url}} <-
                   Storage.store_from_url(avatar.agent_id, source_url),
                 {:ok, avatar} <-
                   update_avatar_and_broadcast(avatar, %{
                     status: :ready,
                     source_url: source_url,
                     output_url: public_url,
                     generated_at: DateTime.utc_now(),
                     error: nil
                   }) do
              {:ok, avatar}
            end
          rescue
            exception -> {:error, exception}
          end

        case result do
          {:ok, avatar} ->
            {:ok, avatar}

          {:error, reason} ->
            {:ok, avatar} =
              update_avatar_and_broadcast(avatar, %{status: :failed, error: format_error(reason)})

            {:error, avatar}
        end
    end
  end

  defp build_avatar_attrs(current_scope, %Agent{} = agent, opts) do
    params = Map.get(opts, :params, %{}) |> normalize_params()

    %{
      tenant_id: current_scope.tenant.id,
      agent_id: agent.id,
      provider: Map.get(opts, :provider, :replicate),
      status: :queued,
      prompt: Map.get(opts, :prompt, default_prompt(agent)),
      params: params
    }
  end

  defp default_prompt(agent) do
    "Sticker-style avatar portrait of #{agent.name}, friendly, clean lines, high contrast, no text"
  end

  defp normalize_params(nil), do: %{}

  defp normalize_params(params) when is_map(params) do
    Map.new(params, fn {key, value} -> {to_string(key), value} end)
  end

  defp fetch_or_create_prediction(%AgentAvatar{prediction_id: prediction_id}, _agent)
       when is_binary(prediction_id) do
    {:ok, Replicate.get_prediction!(prediction_id)}
  end

  defp fetch_or_create_prediction(%AgentAvatar{} = avatar, %Agent{} = agent) do
    Replicate.create_prediction(agent, avatar)
  end

  defp maybe_set_prediction_id(%AgentAvatar{prediction_id: prediction_id} = avatar, _new_id)
       when is_binary(prediction_id) do
    {:ok, avatar}
  end

  defp maybe_set_prediction_id(%AgentAvatar{} = avatar, prediction_id) do
    update_avatar(avatar, %{prediction_id: prediction_id})
  end

  defp update_avatar(%AgentAvatar{} = avatar, attrs) do
    avatar
    |> AgentAvatar.changeset(attrs)
    |> Repo.update()
  end

  defp update_avatar_and_broadcast(%AgentAvatar{} = avatar, attrs) do
    case update_avatar(avatar, attrs) do
      {:ok, avatar} ->
        broadcast_avatar_update(avatar)
        {:ok, avatar}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_error(%MatchError{term: {:error, message}}) when is_binary(message) do
    map_error_message(message)
  end

  defp format_error(%MatchError{term: message}) when is_binary(message) do
    map_error_message(message)
  end

  defp format_error(%{message: message}) when is_binary(message) do
    map_error_message(message)
  end

  defp format_error(reason) when is_binary(reason) do
    map_error_message(reason)
  end

  defp format_error(reason) do
    map_error_message(inspect(reason))
  end

  defp map_error_message(message) do
    if authentication_error?(message) do
      "Replicate auth failed. Check REPLICATE_API_TOKEN."
    else
      message
    end
  end

  defp authentication_error?(message) do
    message
    |> String.downcase()
    |> String.contains?("authentication token")
  end
end
