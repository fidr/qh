defmodule Qh.Repo do
  @doc """
  Update fields in a struct

  Examples:

      user = %MyApp.User{name: nil, age: nil}
      user = Qh.assign(user, name: "Bob", age: 21)

      # or initialize a new record
      user = Qh.assign(:user, name: "Alice", age: 22)
  """
  def assign(schema, params, opts \\ [])

  def assign(%_{} = struct, params, _opts) do
    struct(struct, params)
  end

  def assign(schema, params, opts) do
    struct(Qh.lookup_schema(schema, opts), params)
  end

  @doc """
  Save a struct to the database

  Inserts a new record if no primary key is set
  or no record exists with the current primary key.

  Performs a get and an update if the record already exists.

  Returns `{:ok, struct}` on success or `{:error, validation_errors}` on failure.

  Examples:
      user = %MyApp.User{id: nil, name: "Bob", age: 21}
      {:ok, user} = Qh.save(user)

  """
  def save(%schema{} = struct, opts \\ []) do
    primary_key = schema.__schema__(:primary_key)
    primary_key_values = Map.take(struct, primary_key)
    primary_values = Map.values(primary_key_values)

    if Enum.all?(primary_values, &is_nil/1) do
      # no primary key set, create new new
      params = Map.from_struct(struct)
      changeset = schema.changeset(struct(schema), params)

      Qh.repo(opts).insert(changeset)
      |> handle_repo_result()
    else
      case Qh.repo(opts).get_by(schema, primary_key_values) do
        nil ->
          # no record found, create new
          params = Map.from_struct(struct)
          changeset = schema.changeset(struct(schema), params)

          Qh.repo(opts).insert(changeset)
          |> handle_repo_result()

        current ->
          # record found, update
          params = Map.from_struct(struct)
          changeset = schema.changeset(current, params)

          Qh.repo(opts).update(changeset)
          |> handle_repo_result()
      end
    end
  end

  @doc """
  Save a struct to the database

  Similar to `save/1` but will raise on failures and return only the
  struct on success.

  Examples:
      user = %MyApp.User{id: nil, name: "Bob", age: 21}
      user = Qh.save!(user)

  """
  def save!(%_schema{} = struct, opts \\ []) do
    save(struct, opts) |> ok_or_raise()
  end

  @doc """
  Performs a database update for a struct and params

  Returns `{:ok, struct}` on success or `{:error, validation_errors}` on failure.

  Examples:
      user = %MyApp.User{id: 2, name: "Bob", age: 21}
      {:ok, user} = Qh.update(user, age: 22)

  """
  def update(%schema{} = struct, params, opts \\ []) do
    changeset = schema.changeset(struct, Map.new(params))

    Qh.repo(opts).update(changeset)
    |> handle_repo_result()
  end

  @doc """
  Save a struct to the database

  Similar to `update/1` but will raise on failures and return only the
  struct on success.

  Examples:
      user = %MyApp.User{id: 2, name: "Bob", age: 21}
      user = Qh.update!(user, age: 22)

  """
  def update!(%_schema{} = struct, params, opts \\ []) do
    update(struct, params, opts) |> ok_or_raise()
  end

  @doc """
  Delete a struct in the database

  Will raise if the record doesn't exists

  Examples:
      user = %MyApp.User{id: 2, name: "Bob", age: 21}
      Qh.delete!(user)

  """
  def delete!(%_schema{} = struct, opts \\ []) do
    Qh.repo(opts).delete!(struct)
  end


  defp handle_repo_result({:ok, struct}) do
    {:ok, struct}
  end

  defp handle_repo_result({:error, changeset}) do
    {:error, changeset.errors}
  end

  defp ok_or_raise({:ok, struct}) do
    struct
  end

  defp ok_or_raise({:error, error}) do
    raise inspect(error)
  end
end