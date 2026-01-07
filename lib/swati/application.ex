defmodule Swati.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SwatiWeb.Telemetry,
      Swati.Vault,
      Swati.Repo,
      {Oban, Application.fetch_env!(:swati, Oban)},
      {Ecto.Migrator,
       repos: Application.fetch_env!(:swati, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:swati, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Swati.PubSub},
      # Start a worker by calling: Swati.Worker.start_link(arg)
      # {Swati.Worker, arg},
      # Start to serve requests, typically the last entry
      SwatiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Swati.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SwatiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
