defmodule Swati.Repo.Migrations.AddTenantFormatting do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :formatting, :map,
        null: false,
        default: %{"locale" => "en-IN", "phone_country" => "IN"}
    end
  end
end
