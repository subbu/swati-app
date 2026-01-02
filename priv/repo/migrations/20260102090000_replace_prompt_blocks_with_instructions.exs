defmodule Swati.Repo.Migrations.ReplacePromptBlocksWithInstructions do
  use Ecto.Migration

  @default_instructions "You are Swati, an AI voice agent for swati.ai. Follow the instructions below carefully.\n- Be concise and confirm key details.\n- Respect tool allowlists and policy limits.\n- Escalate to a human when unsure or when safety policy is triggered.\n"

  def change do
    alter table(:agents) do
      remove :prompt_blocks
      add :instructions, :text, null: false, default: @default_instructions
    end
  end
end
