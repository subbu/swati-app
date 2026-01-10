defmodule Swati.Avatars.Providers.Replicate do
  alias Swati.Agents.Agent
  alias Swati.Agents.AgentAvatar

  @model "fofr/sticker-maker"

  def create_prediction(%Agent{} = agent, %AgentAvatar{} = avatar) do
    model = Replicate.Models.get!(@model)
    version = Replicate.Models.get_latest_version!(model)
    input = build_input(agent, avatar)

    Replicate.Predictions.create(version, input)
  end

  def wait(prediction) do
    Replicate.Predictions.wait(prediction)
  end

  def get_prediction!(prediction_id) do
    Replicate.Predictions.get!(prediction_id)
  end

  def first_output_url(prediction) do
    case prediction.output do
      [url | _] when is_binary(url) -> {:ok, url}
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, "missing prediction output"}
    end
  end

  defp build_input(%Agent{} = agent, %AgentAvatar{} = avatar) do
    params = avatar.params || %{}

    params
    |> Map.put_new("prompt", avatar.prompt || default_prompt(agent))
  end

  defp default_prompt(%Agent{} = agent) do
    "Sticker-style avatar portrait of #{agent.name}, friendly, clean lines, high contrast, no text"
  end
end
