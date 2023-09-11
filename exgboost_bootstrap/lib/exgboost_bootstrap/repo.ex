defmodule ExgboostBootstrap.Repo do
  use Ecto.Repo,
    otp_app: :exgboost_bootstrap,
    adapter: Ecto.Adapters.Postgres
end
