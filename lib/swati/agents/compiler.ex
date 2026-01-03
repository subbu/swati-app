defmodule Swati.Agents.Compiler do
  alias Swati.Agents.Agent
  alias Swati.Agents.EscalationPolicy
  alias Swati.Agents.ToolPolicy

  def compile(agent, opts \\ %{}) do
    instructions =
      Map.get(opts, :instructions, agent.instructions || Agent.default_instructions())

    %{
      "agent_id" => agent.id,
      "agent_name" => agent.name,
      "language" => agent.language,
      "voice" => %{
        "provider" => agent.voice_provider,
        "name" => agent.voice_name
      },
      "llm" => %{
        "provider" => agent.llm_provider,
        "model" => agent.llm_model
      },
      "system_prompt" => instructions,
      "tool_policy" => ToolPolicy.normalize(agent.tool_policy),
      "escalation_policy" => EscalationPolicy.normalize(agent.escalation_policy)
    }
  end
end
