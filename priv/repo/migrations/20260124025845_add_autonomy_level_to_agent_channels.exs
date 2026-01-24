defmodule Swati.Repo.Migrations.AddAutonomyLevelToAgentChannels do
  use Ecto.Migration

  def change do
    alter table(:agent_channels) do
      add :autonomy_level, :string, default: "draft"
    end
  end
end
