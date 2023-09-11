defmodule ExgboostBootstrapWeb.ErrorJSONTest do
  use ExgboostBootstrapWeb.ConnCase, async: true

  test "renders 404" do
    assert ExgboostBootstrapWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ExgboostBootstrapWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
