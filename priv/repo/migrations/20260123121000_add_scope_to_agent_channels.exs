defmodule Swati.Repo.Migrations.AddScopeToAgentChannels do
  use Ecto.Migration

  def change do
    alter table(:agent_channels) do
      add_if_not_exists :scope, :map, default: %{"mode" => "all"}
    end
  end
end
