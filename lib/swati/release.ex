defmodule Swati.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :swati

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end

  # Add this to lib/swatiai/release.ex

  def backport_phone_number(e164, country, region, user_id) do
    start_app()

    user_id = String.to_integer(user_id)

    IO.puts("Backporting phone number: #{e164}")
    IO.puts("Country: #{country}, Region: #{region}")
    IO.puts("User ID: #{user_id}")

    user = Swatiai.Accounts.get_user!(user_id)
    IO.puts("Found user: #{user.email}")

    attrs = %{
      e164: e164,
      country: country,
      region: region,
      user_id: user_id
    }

    case Swatiai.PhoneNumbers.create_phone_number(attrs) do
      {:ok, phone_number} ->
        IO.puts("✓ Successfully backported phone number: #{phone_number.e164}")
        {:ok, phone_number}

      {:error, changeset} ->
        IO.puts("✗ Failed to backport phone number")
        IO.inspect(changeset.errors)
        {:error, changeset}
    end
  end

  defp start_app do
    load_app()
    Application.ensure_all_started(:swatiai)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
