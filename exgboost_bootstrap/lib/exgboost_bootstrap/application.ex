defmodule ExgboostBootstrap.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ExgboostBootstrapWeb.Telemetry,
      # Start the Ecto repository
      ExgboostBootstrap.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: ExgboostBootstrap.PubSub},
      # Start Finch
      {Finch, name: ExgboostBootstrap.Finch},
      # Start the Endpoint (http/https)
      ExgboostBootstrapWeb.Endpoint
      # Start a worker by calling: ExgboostBootstrap.Worker.start_link(arg)
      # {ExgboostBootstrap.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExgboostBootstrap.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExgboostBootstrapWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
