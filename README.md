# elixir_exgboost_bootstrap

```zsh
docker-compose up -d
cd exgboost_bootstrap

mix deps.get
mix deps.compile
mix ecto.create
mix phx.server

```

Data comes from the [Kaggle Fraud dataset](https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud). 

