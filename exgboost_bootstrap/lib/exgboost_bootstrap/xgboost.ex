defmodule MlXgboost do
  require Explorer.DataFrame, as: DF

  @credit_cards_path "../dataset/creditcard.csv"
  # @credit_cards_path "/Users/olivierdeprez/Library/CloudStorage/OneDrive-Personnel/Boulot/7lieues/PRODUCT/Technical_stuff/Code/sources/livebook_fun/datasets/creditcard.csv"

  @doc """
  Returns a dataframe loaded from dataset CSV (or else) file.
  Default file is provided in the git repo under ../dataset.

  iex(1)> df = MlXgboost.load()
  #Explorer.DataFrame<
  Polars[284807 x 31]
  Time float [0.0, 0.0, 1.0, 1.0, 2.0, ...]
  V1 float [-1.3598071336738, 1.19185711131486, -1.35835406159823,
   -0.966271711572087, -1.15823309349523, ...]
   ...
   >
  """
  def load(path \\ @credit_cards_path) do
    Explorer.DataFrame.from_csv!(path, dtypes: [{"Time", :float}])
  end

  @doc """
  Needs a Dataframe.
  Split it into train (80%) and test (20%) and return it as a tuple.

  iex> split_train_test(df)
  {#Explorer.DataFrame<
   Polars[166881 x 31]
   Time float [43761.0, 78704.0, 74780.0, 20931.0, 117414.0, ...]
   V1 float [-2.47086795609139, 1.2153333420191, 1.19265447076012,
    -16.3679230107968, 2.06827320890476, ...]
    ...
    >,
  #Explorer.DataFrame<
   Polars[41720 x 31]
   Time float [47954.0, 71724.0, 120395.0, 72204.0, 96841.0, ...]
   V1 float [1.04515368949019, -0.747389481690982, 1.4181253683918,
    1.24120991428222, 2.10138137555747, ...]
    ...}

  iex> split_train_test(df, 100)
  {#Explorer.DataFrame<
   Polars[81 x 31]
   Time float [26.0, 50.0, 41.0, 67.0, 64.0, ...]
   V1 float [-0.529912284186556, -0.571520749961747, 1.1387593359078,
    -0.653444627294995, -0.658304934095684, ...]
    ...
    >,
  #Explorer.DataFrame<
   Polars[20 x 31]
   Time float [53.0, 34.0, 16.0, 40.0, 51.0, ...]
   V1 float [-1.19896767411718, -0.291540244596543, 0.694884775607337,
    1.11069200372208, 1.25987313565004, ...]
    ...
    >}
  """
  def split_train_test(df, dataset_limit \\ 208_600, reverse_shrink \\ false) do
    df = df |> shrink_dataset(dataset_limit, reverse_shrink)

    n_rows = DF.n_rows(df)
    split_at = floor(0.8 * n_rows)

    df = DF.shuffle(df)
    train_df = DF.slice(df, 0..split_at)
    test_df = DF.slice(df, split_at..-1)

    {train_df, test_df}
  end

  defp shrink_dataset(df, nb_rows, true) do
    total_rows = DF.n_rows(df)
    df |> Explorer.DataFrame.slice(total_rows - nb_rows, total_rows)
  end

  defp shrink_dataset(df, nb_rows, _) do
    df |> Explorer.DataFrame.slice(0, nb_rows)
  end

  @doc """
  Target is the column that will serve as objective.
  Features are all the other columns.

  In our dataset example target is "Class" column.

  iex> {train_df, test_df} |> MlXgboost.stack_to_nx()
  {#Nx.Tensor<
   f64[81][30]
   [
     [22.0, -2.0742946722629, -0.121481799450951, ...],
     ...
    ]
  >,
  #Nx.Tensor<
   s64[81][1]
   [
     [0],
     [0],
     [0],
     ...
   ]
  >,
  #Nx.Tensor<
   f64[20][30]
   [
     [48.0, -0.580628965016257, ...],
     ...
     ]
     >,
  #Nx.Tensor<
   s64[20][1]
   [
     [0],
     [0],
     [0],
     ...
     ]
  >}
  """

  def stack_to_nx({train_df, test_df}, target \\ "Class") do
    x_train = Explorer.DataFrame.select(train_df, &(&1 != target)) |> Nx.stack(axis: 1)
    x_test = Explorer.DataFrame.select(test_df, &(&1 != target)) |> Nx.stack(axis: 1)

    y_train = Explorer.DataFrame.select(train_df, &(&1 == target)) |> Nx.stack(axis: 1)
    y_test = Explorer.DataFrame.select(test_df, &(&1 == target)) |> Nx.stack(axis: 1)

    {x_train, y_train, x_test, y_test}
  end

  @doc """
  Returns a trained XGBoost model.
  :binary_logistic seems a good objective function for our dataset example.

  Have tested :reg_squarederror also (with Target conevrted as float), and same 'bus error' occurs at the same dataset length (208601 lines).
  Have tested with booster: :gblinear, :dart (besides default :gbtree), still same 'bus error' at the same dataset length (208601 lines).
  With or without :tree_method result is the same. Been tested with no max_depth also.

  iex> x_train |> MlXgboost.build_model(y_train, {x_test, y_test})
  Iteration 0: %{"test" => %{"rmse" => 0.0}}
  Iteration 1: %{"test" => %{"rmse" => 0.0}}
  Iteration 2: %{"test" => %{"rmse" => 0.0}}
  Iteration 3: %{"test" => %{"rmse" => 0.0}}
  %EXGBoost.Booster{
  ref: #Reference<0.1643606743.3911057409.37047>,
  best_iteration: 4,
  best_score: 0.0
  }
  """
  def build_model(x_train, y_train, {x_test, y_test}) do
    EXGBoost.train(
      x_train,
      y_train,
      obj: :binary_logistic,
      evals: [{x_test, y_test, "test"}],
      max_depth: 0,
      tree_method: :approx,
      learning_rates: fn i -> i / 100 end,
      num_boost_round: 10,
      early_stopping_rounds: 3,
      params: [max_depth: 3, eval_metric: ["error", "roc", "auc"]]
    )
  end

  @doc """
  returns y_pred
  """
  def predict(model, x_test) do
    EXGBoost.predict(model, x_test)
  end

  @doc """
  Returns absolute error.
  """
  def measure_abs_error(y_test, y_pred) do
    Nx.abs(Nx.subtract(Nx.squeeze(y_test), y_pred))
  end

  # @doc """
  # Returns mean absolute error
  # Needs {:scholar, "~> 0.1"}
  # """

  # def measure_mae(y_test, y_pred) do
  #   Scholar.Metrics.Regression.mean_absolute_error(Nx.squeeze(y_test), y_pred)
  # end

  # @doc """
  # Returns MAPE (mean_absolute_percentage_error)
  # Needs {:scholar, "~> 0.1"}
  # """

  # def measure_mape(y_test, y_pred) do
  #   Scholar.Metrics.Regression.mean_absolute_percentage_error(Nx.squeeze(y_test), y_pred)
  # end

  defp to_xgboost(tensor) do
    tensor |> Nx.stack(axis: 1)
  end

  @doc """
  tests a random elem in dataframe

  Needs features like:
  features = ~w(Time V1 V2 V3 Amount)

  Run it like:
  iex> MlXgboost.run()

  """
  def test_random(df, model, features) do
    sample_test = df |> DF.sample(1)

    model
    |> EXGBoost.predict(to_xgboost(sample_test[features]))
  end

  @doc """
  Runs the MlXgboost Module.

  Defaults to 208_600 nb_rows:
  % iex -S mix phx.server
  iex> MlXgboost.run()

  If 208_601 lines, then crashes the Erlang VM:
  % iex -S mix phx.server
  iex> MlXgboost.run(208_601)
  zsh: bus error  iex -S mix phx.server

  Reverse dataframe slice gives the same result:
  % iex -S mix phx.server
  iex> MlXgboost.run(208_601, true)
  zsh: bus error  iex -S mix phx.server

  """
  def run(dataset_limit \\ 208_600, reverse_shrink \\ false) do
    df = load()

    {x_train, y_train, x_test, y_test} =
      df
      |> split_train_test(dataset_limit, reverse_shrink)
      |> stack_to_nx()

    model = x_train |> build_model(y_train, {x_test, y_test})

    y_pred =
      EXGBoost.predict(model, x_test)

    y_test |> measure_abs_error(y_pred)
  end
end
