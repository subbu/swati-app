defmodule Swati.Preferences do
  import Ecto.Query, warn: false

  alias Swati.Accounts.Scope
  alias Swati.Preferences.Definitions
  alias Swati.Preferences.Preference
  alias Swati.Repo
  alias Swati.Tenancy

  def calls_index_key, do: Definitions.calls_index_key()
  def calls_index_columns, do: Definitions.calls_index_columns()
  def calls_index_defaults, do: Definitions.calls_index_defaults()
  def sessions_index_key, do: Definitions.sessions_index_key()
  def sessions_index_columns, do: Definitions.sessions_index_columns()
  def sessions_index_defaults, do: Definitions.sessions_index_defaults()
  def cases_index_key, do: Definitions.cases_index_key()
  def cases_index_columns, do: Definitions.cases_index_columns()
  def cases_index_defaults, do: Definitions.cases_index_defaults()

  def calls_index_state(%Scope{} = current_scope) do
    get(current_scope, calls_index_key())
  end

  def update_calls_index_state(%Scope{} = current_scope, updates) do
    put(current_scope, calls_index_key(), updates)
  end

  def sessions_index_state(%Scope{} = current_scope) do
    get(current_scope, sessions_index_key())
  end

  def update_sessions_index_state(%Scope{} = current_scope, updates) do
    put(current_scope, sessions_index_key(), updates)
  end

  def cases_index_state(%Scope{} = current_scope) do
    get(current_scope, cases_index_key())
  end

  def update_cases_index_state(%Scope{} = current_scope, updates) do
    put(current_scope, cases_index_key(), updates)
  end

  def get(%Scope{} = current_scope, key) do
    if missing_scope?(current_scope) do
      Definitions.default(key)
    else
      value =
        Preference
        |> Tenancy.scope(current_scope.tenant.id)
        |> where([pref], pref.user_id == ^current_scope.user.id)
        |> where([pref], pref.key == ^key)
        |> select([pref], pref.value)
        |> Repo.one()

      Definitions.normalize(key, value)
    end
  end

  def put(%Scope{} = current_scope, key, updates) do
    if missing_scope?(current_scope) do
      {:error, :missing_scope}
    else
      merged = Definitions.merge(key, get(current_scope, key), updates)
      upsert(current_scope, key, merged)
    end
  end

  defp upsert(current_scope, key, value) do
    schema_version = Definitions.schema_version(key)
    attrs = %{key: key, value: value, schema_version: schema_version}

    %Preference{tenant_id: current_scope.tenant.id, user_id: current_scope.user.id}
    |> Preference.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          value: value,
          schema_version: schema_version,
          updated_at: DateTime.utc_now()
        ]
      ],
      conflict_target: [:tenant_id, :user_id, :key]
    )
  end

  defp missing_scope?(current_scope) do
    is_nil(current_scope.user) or is_nil(current_scope.tenant)
  end
end
