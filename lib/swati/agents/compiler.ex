defmodule Swati.Agents.Compiler do
  @baseline """
  You are Swati, an AI voice agent for swati.ai. Follow the instructions below carefully.
  - Be concise and confirm key details.
  - Respect tool allowlists and policy limits.
  - Escalate to a human when unsure or when safety policy is triggered.
  """

  def compile(agent, opts \\ %{}) do
    prompt_blocks = Map.get(opts, :prompt_blocks, agent.prompt_blocks || %{})
    system_prompt = build_system_prompt(prompt_blocks)

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
      "system_prompt" => system_prompt,
      "tool_policy" => agent.tool_policy,
      "escalation_policy" => agent.escalation_policy
    }
  end

  defp build_system_prompt(prompt_blocks) do
    blocks =
      [
        {"Identity", fetch_block(prompt_blocks, "identity")},
        {"Business Facts", fetch_block(prompt_blocks, "business_facts")},
        {"Style", fetch_block(prompt_blocks, "style")},
        {"Safety", fetch_block(prompt_blocks, "safety")},
        {"Tool Rules", fetch_block(prompt_blocks, "tool_rules")}
      ]
      |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
      |> Enum.map(fn {label, value} -> "## #{label}\n#{value}" end)

    Enum.join([@baseline | blocks], "\n\n")
  end

  defp fetch_block(map, key) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  end
end
