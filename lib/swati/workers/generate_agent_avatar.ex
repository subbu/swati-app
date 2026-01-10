defmodule Swati.Workers.GenerateAgentAvatar do
  use Oban.Worker, queue: :media, max_attempts: 3

  alias Swati.Avatars

  @impl true
  def perform(%Oban.Job{args: %{"avatar_id" => avatar_id}}) do
    case Avatars.generate_avatar(avatar_id) do
      {:ok, _avatar} -> :ok
      {:error, _reason} -> :ok
    end
  end

  def perform(%Oban.Job{}), do: :ok
end
