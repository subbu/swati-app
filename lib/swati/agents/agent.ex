defmodule Swati.Agents.Agent do
  use Swati.DbSchema

  @statuses ["draft", "active", "archived"]
  @prompt_keys ["identity", "business_facts", "style", "safety", "tool_rules"]
  @prompt_atoms [:identity, :business_facts, :style, :safety, :tool_rules]

  schema "agents" do
    field :name, :string
    field :status, :string, default: "draft"
    field :language, :string, default: "en-IN"
    field :voice_provider, :string, default: "google"
    field :voice_name, :string, default: "Fenrir"
    field :llm_provider, :string, default: "google"
    field :llm_model, :string
    field :prompt_blocks, :map
    field :tool_policy, :map
    field :escalation_policy, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :published_version, Swati.Agents.AgentVersion

    has_many :versions, Swati.Agents.AgentVersion
    has_many :agent_integrations, Swati.Agents.AgentIntegration

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
      :prompt_blocks,
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
      :prompt_blocks,
      :tool_policy
    ])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_inclusion(:status, @statuses)
    |> validate_prompt_blocks()
    |> validate_tool_policy()
    |> unique_constraint(:name, name: :agents_tenant_id_name_index)
  end

  def default_prompt_blocks do
    %{
      "identity" => "You are Swati, a helpful voice agent.",
      "business_facts" => "",
      "style" => "Be concise, warm, and confirm key details.",
      "safety" => "Never request sensitive data. Escalate when unsure.",
      "tool_rules" => "Only call approved tools when needed."
    }
  end

  def default_tool_policy do
    %{
      "allow" => [],
      "deny" => [],
      "max_calls_per_turn" => 3
    }
  end

  def default_llm_model do
    System.get_env(
      "SWATI_DEFAULT_LLM_MODEL",
      "models/gemini-2.5-flash-native-audio-preview-12-2025"
    )
  end

  defp validate_prompt_blocks(changeset) do
    validate_change(changeset, :prompt_blocks, fn :prompt_blocks, value ->
      cond do
        not is_map(value) ->
          [prompt_blocks: "must be a map"]

        missing_prompt_keys(value) != [] ->
          missing = Enum.join(missing_prompt_keys(value), ", ")
          [prompt_blocks: "missing keys: #{missing}"]

        true ->
          []
      end
    end)
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

  defp missing_prompt_keys(value) do
    @prompt_keys
    |> Enum.zip(@prompt_atoms)
    |> Enum.filter(fn {key, atom_key} ->
      not (Map.has_key?(value, key) or Map.has_key?(value, atom_key))
    end)
    |> Enum.map(fn {key, _atom_key} -> key end)
  end
end
