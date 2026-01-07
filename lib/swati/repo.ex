defmodule Swati.Repo do
  use Ecto.Repo,
    otp_app: :swati,
    adapter: Ecto.Adapters.Postgres
end
