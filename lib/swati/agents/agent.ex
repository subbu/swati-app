defmodule Swati.Agents.Agent do
  use Swati.DbSchema

  alias Swati.Agents.ToolPolicy

  @statuses ["draft", "active", "archived"]
  schema "agents" do
    field :name, :string
    field :status, :string, default: "draft"
    field :language, :string, default: "en-IN"
    field :voice_provider, :string, default: "google"
    field :voice_name, :string, default: "Fenrir"
    field :llm_provider, :string, default: "google"
    field :llm_model, :string
    field :instructions, :string
    field :tool_policy, :map
    field :escalation_policy, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :published_version, Swati.Agents.AgentVersion

    has_many :versions, Swati.Agents.AgentVersion
    has_many :agent_integrations, Swati.Agents.AgentIntegration
    has_many :agent_webhooks, Swati.Agents.AgentWebhook
    has_many :avatars, Swati.Agents.AgentAvatar

    timestamps()
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [
      :tenant_id,
      :name,
      :status,
      :language,
      :voice_provider,
      :voice_name,
      :llm_provider,
      :llm_model,
      :instructions,
      :tool_policy,
      :escalation_policy,
      :published_version_id
    ])
    |> validate_required([
      :tenant_id,
      :name,
      :status,
      :language,
      :voice_provider,
      :voice_name,
      :llm_provider,
      :llm_model,
      :instructions,
      :tool_policy
    ])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_inclusion(:status, @statuses)
    |> validate_tool_policy()
    |> unique_constraint(:name, name: :agents_tenant_id_name_index)
  end

  def default_instructions do
    "You are Swati, an AI voice agent for swati.ai. Follow the instructions below carefully.\n- Be concise and confirm key details.\n- Respect tool allowlists and policy limits.\n- Escalate to a human when unsure or when safety policy is triggered.\n"
  end

  def default_tool_policy do
    ToolPolicy.default()
  end

  def default_llm_model do
    System.get_env(
      "SWATI_DEFAULT_LLM_MODEL",
      "models/gemini-2.5-flash-native-audio-preview-12-2025"
    )
  end

  defp validate_tool_policy(changeset) do
    validate_change(changeset, :tool_policy, fn :tool_policy, value ->
      cond do
        not is_map(value) ->
          [tool_policy: "must be a map"]

        not is_list(Map.get(value, "allow") || Map.get(value, :allow)) ->
          [tool_policy: "allow must be a list"]

        not is_list(Map.get(value, "deny") || Map.get(value, :deny)) ->
          [tool_policy: "deny must be a list"]

        not is_integer(
          Map.get(value, "max_calls_per_turn") || Map.get(value, :max_calls_per_turn)
        ) ->
          [tool_policy: "max_calls_per_turn must be an integer"]

        true ->
          []
      end
    end)
  end
end
