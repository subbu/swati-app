defmodule Swati.Repo.Migrations.AddPromptSectionsToAgents do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :prompt_sections, :map
    end
  end
end
