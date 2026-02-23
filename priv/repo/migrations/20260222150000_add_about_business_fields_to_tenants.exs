defmodule Swati.Repo.Migrations.AddAboutBusinessFieldsToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :business_identity, :text, null: false, default: ""
      add :business_brand_voice, :text, null: false, default: ""
      add :business_operating_boundaries, :text, null: false, default: ""
      add :business_escalation_map, :text, null: false, default: ""
      add :business_top_workflows, :text, null: false, default: ""
    end
  end
end
