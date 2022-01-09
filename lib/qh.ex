defmodule Qh do
  @moduledoc """
  Query helper for iex

  `.iex.exs`:

  ```
  use Qh

  Qh.configure(app: :my_app)
  ```

  ## Example:

      iex>q User.where(age > 20 and age < 50).order(name).first
      %MyApp.User%{id: 123, age: 21, name: "Anna"}
  """

  defmacro __using__(_) do
    quote do
      require Qh
      import Qh, only: [q: 1, q: 2]
    end
  end

  @doc """
  Run a query

  Examples:
      use Qh

      Qh.configure(app: :my_app)

      q User.first
      q User.order(name).last(3)
      q User.order(name: :asc, age: :desc).last
      q User.order("lower(?)", name).last
      q User.where(age > 20 and age <= 30).count
      q User.where(age > 20 and age <= 30).limit(10).all
      q User.where(age > 20 or name == "Bob").all
      q User.where(age > 20 and (name == "Bob" or name == "Anna")).all
      q User.where(age: 20, name: "Bob").count
      q User.where("nicknames && ?", ["Bobby", "Bobi"]).count
      q User.where("? = ANY(?)", age, [20, 30, 40]).count
      q User.find(21)
      q User.find_by(name: "Bob Foo")
      q User.find_by(name == "Bob" or name == "Anna")

      # Initialize new
      user = q User.new(name: "Bob")
  """
  defmacro q(q, opts \\ []) do
    [schema | rest] = unwrap_nested(q)

    code = [
      quote do
        require Ecto.Query
        query = Qh.lookup_schema(unquote(schema), unquote(opts))
      end
    ]

    code =
      code ++
        Enum.map(rest, fn
          {:order, _, [q | _rest] = fragment} when is_binary(q) ->
            fragment = deep_prefix_binding(fragment)

            quote do
              query = Ecto.Query.order_by(query, [t], fragment(unquote_splicing(fragment)))
            end

          {:order, _, [order]} ->
            order =
              Enum.map(List.wrap(order), fn
                {_k, _, nil} = part -> deep_prefix_binding(part)
                {key, dir} -> {dir, deep_prefix_binding(key)}
              end)

            quote do
              query = Ecto.Query.order_by(query, [t], unquote(order))
            end

          {:where, _, [q | _rest] = fragment} when is_binary(q) ->
            fragment = deep_prefix_binding(fragment)

            quote do
              query = Ecto.Query.where(query, [t], fragment(unquote_splicing(fragment)))
            end

          {:where, _, [conditions]} ->
            conditions = deep_prefix_binding(conditions)

            quote do
              query = Ecto.Query.where(query, [t], unquote(conditions))
            end

          {:limit, _, [n]} ->
            quote do
              query = Ecto.Query.limit(query, unquote(n))
            end

          {:find, _, [id]} ->
            quote do
              Qh.repo(unquote(opts)).get!(query, unquote(id))
            end

          {:find_by, _, [q | _rest] = fragment} when is_binary(q) ->
            fragment = deep_prefix_binding(fragment)

            quote do
              Ecto.Query.where(query, [t], fragment(unquote_splicing(fragment)))
              |> Ecto.Query.limit(1)
              |> Qh.repo(unquote(opts)).all()
              |> List.first()
            end

          {:find_by, _, [condition]} ->
            condition = deep_prefix_binding(condition)

            quote do
              Ecto.Query.where(query, [t], unquote(condition))
              |> Ecto.Query.limit(1)
              |> Qh.repo(unquote(opts)).all()
              |> List.first()
            end

          {:count, _, _} ->
            quote do
              Qh.repo(unquote(opts)).aggregate(query, :count)
            end

          {:first, _, []} ->
            quote do
              Ecto.Query.limit(query, 1)
              |> Qh.default_primary_order()
              |> Qh.repo(unquote(opts)).one()
            end

          {:first, _, [n]} ->
            quote do
              Ecto.Query.limit(query, unquote(n))
              |> Qh.default_primary_order()
              |> Qh.repo(unquote(opts)).all()
            end

          {:last, _, []} ->
            quote do
              Ecto.Query.reverse_order(query)
              |> Ecto.Query.limit(1)
              |> Qh.default_primary_order()
              |> Qh.repo(unquote(opts)).one()
            end

          {:last, _, [n]} ->
            quote do
              Ecto.Query.reverse_order(query)
              |> Ecto.Query.limit(unquote(n))
              |> Qh.default_primary_order()
              |> Qh.repo(unquote(opts)).all()
              |> Enum.reverse()
            end

          {:select, _, target} ->
            target =
              target
              |> unwrap_single()
              |> deep_prefix_binding()

            quote do
              query
              |> Ecto.Query.select([t], unquote(target))
              |> Qh.repo(unquote(opts)).all()
            end

          {:all, _, []} ->
            quote do
              query
              |> Qh.repo(unquote(opts)).all()
            end

          {:new, _, []} ->
            quote do
              schema = Qh.get_schema(query)
              struct(schema)
            end

          {:new, _, [params]} ->
            quote do
              schema = Qh.get_schema(query)
              struct(schema, unquote(params))
            end
        end)

    quote do
      (unquote_splicing(code))
    end
  end

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

  defp deep_prefix_binding(tree) do
    prewalk_cond(tree, fn
      {:^, _, _} = node ->
        {false, node}

      {field, _, nil} ->
         {false, {{:., [], [{:t, [], nil}, field]}, [no_parens: true], []}}

      node ->
        {true, node}
    end)
  end

  defp unwrap_single([item]), do: item
  defp unwrap_single(other), do: other

  defp unwrap_nested({{:., _, [left, right]}, opts, children}) do
    parens = if opts[:no_parens], do: false, else: true

    unwrap_nested(left) ++ [{right, [parens: parens], children}]
  end

  defp unwrap_nested({k, _, nil}), do: [k]
  defp unwrap_nested(v), do: [v]

  def repo(opts \\ []) do
    repo_mod(opts)
  end

  def lookup_schema(schema, opts \\ []) do
    app_mod = app_mod(opts)

    cond do
      is_atom(schema) and first_uppercase?(schema) and ensure_compiled?(schema) ->
        schema

      first_uppercase?(schema) ->
        module = Module.concat(app_mod, schema)
        module_or_raise!(module, schema)

      true ->
        module = Module.concat(app_mod, Macro.camelize(to_string(schema)))
        module_or_raise!(module, schema)
    end
  end

  def repo_mod(opts) do
    opts[:repo] || Application.get_env(:qh, :repo) || Module.concat(app_mod(opts), Repo)
  end

  def app_mod(opts) do
    opts[:app_mod] ||  maybe_camelize(opts[:app]) || Application.get_env(:qh, :app_mod) || maybe_camelize(Application.get_env(:qh, :app))
  end

  def configure(opts) do
    Enum.each(opts, fn {k, v} ->
      Application.put_env(:qh, k, v)
    end)
  end

  def default_primary_order(schema) when is_atom(schema) do
    require Ecto.Query
    primary_key = schema.__schema__(:primary_key)
    Ecto.Query.order_by(schema, ^primary_key)
  end

  def default_primary_order(%{from: %{source: {_, schema}}, order_bys: []} = query) do
    require Ecto.Query
    primary_key = schema.__schema__(:primary_key)
    Ecto.Query.order_by(query, ^primary_key)
  end

  def default_primary_order(unknown), do: unknown

  def get_schema(schema) when is_atom(schema) do
    schema
  end

  def get_schema(%{from: %{source: {_, schema}}}) do
    schema
  end

  defp module_or_raise!(module, schema) do
    if ensure_compiled?(module) do
      module
    else
      raise "unable to find schema for #{inspect(schema)}, #{inspect(module)} does not exist"
    end
  end

  defp first_uppercase?(val) do
    String.at(to_string(val), 0) == String.capitalize(String.at(to_string(val), 0))
  end

  defp ensure_compiled?(module) do
    case Code.ensure_compiled(module) do
      {:module, _} ->
        true

      {:error, _} ->
        false
    end
  end

  defp maybe_camelize(nil), do: nil
  defp maybe_camelize(val), do: Macro.camelize(to_string(val))

  defp prewalk_cond(tree, fun) do
    apply_and_maybe_descend(tree, fun)
  end

  defp do_prewalk_cond({form, meta, args}, fun) when is_atom(form) do
    {form, meta, do_prewalk_cond_args(args, fun)}
  end

  defp do_prewalk_cond({form, meta, args}, fun) do
    {apply_and_maybe_descend(form, fun), meta, do_prewalk_cond_args(args, fun)}
  end

  defp do_prewalk_cond({left, right}, fun) do
    {apply_and_maybe_descend(left, fun), apply_and_maybe_descend(right, fun)}
  end

  defp do_prewalk_cond(list, fun) when is_list(list) do
    do_prewalk_cond_args(list, fun)
  end

  defp do_prewalk_cond(x, _fun) do
    x
  end

  defp do_prewalk_cond_args(args, _fun) when is_atom(args) do
    args
  end

  defp do_prewalk_cond_args(args, fun) when is_list(args) do
    Enum.map(args, fn node -> apply_and_maybe_descend(node, fun) end)
  end

  defp apply_and_maybe_descend(node, fun) do
    case fun.(node) do
      {true, node} ->
        do_prewalk_cond(node, fun)

      {false, node} ->
        node
    end
  end
end
