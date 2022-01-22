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

  defmacro q(query, opts \\ []) do
    Qh.query(query, opts, __CALLER__)
  end


  def configure(opts) do
    Enum.each(opts, fn {k, v} ->
      Application.put_env(:qh, k, v)
    end)
  end

  @doc """
  Run a query

  Examples:

      # First/last
      q User.first
      q User.first(10)
      q User.last
      q User.last(1)

      # Custom order
      q User.order(name).last(3)
      q User.order(name: :asc, age: :desc).last
      q User.order("lower(?)", name).last

      # Conditions
      q User.where(age > 20 and age <= 30).count
      q User.where(age > 20 and age <= 30).limit(10).all
      q User.where(age > 20 or name == "Bob").all
      q User.where(age > 20 and (name == "Bob" or name == "Anna")).all
      q User.where(age: 20, name: "Bob").count
      q User.where("nicknames && ?", ["Bobby", "Bobi"]).count
      q User.where("? = ANY(?)", age, [20, 30, 40]).count

      # Opional binding
      q User.where([u], u.age > 20 and u.age <= 30).count

      # Find
      q User.get!(21)
      # or
      q User.find(21)

      # Alias for where(...).first
      q User.find_by(name: "Bob Foo")
      q User.find_by(name == "Bob" or name == "Anna")

      # Aggregations
      q User.group_by("length(name)").count
      q User.group_by(name).avg(age)

      # Select stats
      q User.select(count(), avg(age), min(age), max(age)).all

      # Aggregate stats grouped by column
      q User.group_by(name).aggr(%{count: count(), avg: avg(age), min: min(age), max: max(age)})

      # Count number of messages per user
      q User.left_join(:messages).group_by(id).count([u, m], m.id)

      # Grab only users that have messages
      q User.distinct(id).join(:messages).all

      # Custom join logic
      q User.join([u], u in MyApp.Messages, on: u.id == m.sent_by_id, as: :m)

  """
  def query(q, opts \\ [], caller \\ __ENV__) do
    [schema | rest] = unwrap_nested(q)

    code =
      if is_atom(schema) && !first_uppercase?(schema) do
        quote do
          require Ecto.Query
          query = unquote({schema, [if_undefined: :apply], nil})
        end
      else
        quote do
          require Ecto.Query
          query = Qh.lookup_schema(unquote(schema), unquote(opts))
        end
      end

    # aliases
    rest =
      Enum.flat_map(rest, fn
        {:order, _, params} ->
          [{:order_by, [], params}]

        {:find, _, params} ->
          [{:get, [], params}]

        {:find_by, _, params} ->
          [{:where, [], params}, {:first, [], []}]

        {fun, _, params} when fun in [:count, :sum, :avg, :min, :max] ->
          if first_param_binding?(params) do
            [binding | params] = params
            [{:aggr, [], [binding, {fun, [], params}]}]
          else
            [{:aggr, [], [{fun, [], params}]}]
          end

        other ->
          [other]
      end)

    code =
      [code] ++
        Enum.map(rest, fn
          # Ecto.Query functions /3 (with binding)
          {fun, _, params}
          when fun in [
                 :distinct,
                 :where,
                 :select,
                 :select_merge,
                 :group_by,
                 :having,
                 :lock,
                 :or_having,
                 :or_where,
                 :order_by,
                 :preload,
                 :windows,
                 :limit
               ] ->
            transform_with_binding(fun, params)

          # Ecto.Query functions /2
          {fun, _, params}
          when fun in [
                 :except,
                 :except_all,
                 :exclude,
                 :intersect,
                 :intersect_all,
                 :union,
                 :union_all
               ] ->
            quote do
              query = Ecto.Query.unquote(fun)(query, unquote_splicing(params))
            end

          # Ecto.Query functions /1
          {fun, _, []}
          when fun in [
                 :reverse_order
               ] ->
            quote do
              query = Ecto.Query.unquote(fun)(query)
            end

          # Repo functions /1
          {fun, _, []} when fun in [:all, :one, :stream, :exists?] ->
            quote do
              Qh.repo(unquote(opts)).unquote(fun)(query)
            end

          # Quick or custom join
          {join, _, params}
          when join in [
                 :join,
                 :inner_join,
                 :left_join,
                 :right_join,
                 :cross_join,
                 :full_join,
                 :inner_lateral_join,
                 :left_lateral_join
               ] ->
            transform_join(join, params)

          # Aggregrate respecting group_bys
          {:aggr, _, params} ->
            transform_aggr(params, caller, opts)

          # Return a queryable
          {:query, _, []} ->
            quote do
              query = Ecto.Queryable.to_query(query)
            end

          # First/last
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

    code =
      quote do
        (unquote_splicing(code))
      end

    #IO.puts(Macro.to_string(code))

    code
  end

  # Transform

  def transform_join(fun, params) do
    type =
      case String.split(to_string(fun), "_", parts: 2) do
        ["join"] -> :inner
        [type, "join"] -> String.to_atom(type)
      end

    case params do
      [target] when is_atom(target) ->
        quote do
          query = Ecto.Query.join(query, unquote(type), [t], assoc(t, unquote(target)))
        end

      [target, as] when is_atom(target) and is_atom(as) ->
        quote do
          query =
            Ecto.Query.join(query, unquote(type), [t], assoc(t, unquote(target)),
              as: unquote(as)
            )
        end

      [target, {as, _, nil}] when is_atom(target) and is_atom(as) ->
        quote do
          query =
            Ecto.Query.join(query, unquote(type), [t], assoc(t, unquote(target)),
              as: unquote(as)
            )
        end

      params ->
        {binding_provided, binding, params} = Qh.split_optional_binding(params)

        params = Qh.Expr.maybe_deep_prefix_binding(binding_provided, params)

        quote do
          query =
            Ecto.Query.join(
              query,
              unquote(type),
              unquote(binding),
              unquote_splicing(params)
            )
        end
    end
  end

  def transform_aggr(original_params, caller, opts) do
    {binding_provided, binding, params} = Qh.split_optional_binding(original_params)

    {_, binding} =
      Ecto.Query.Builder.escape_binding(quote(do: %Ecto.Query{}), binding, caller)

    prefixed_params = unwrap_single(params)

    prefixed_params = Qh.Expr.maybe_deep_prefix_binding(binding_provided, prefixed_params)

    {prefixed_params, _take} =
      Ecto.Query.Builder.Select.escape(prefixed_params, binding, caller)

    call_select = transform_with_binding(:select, original_params)

    quote do
      query =
        if Qh.has_group_by?(query) do
          query
          |> Qh.group_by_and_aggregate(unquote(prefixed_params))
          |> Qh.repo(unquote(opts)).all()
        else
          unquote(call_select)
          |> Qh.repo(unquote(opts)).one()
        end
    end
  end

  def group_by_and_aggregate(query, target) do
    {first_group_by, joined_expr} =
      case query.group_bys do
        [group_by] ->
          {group_by, unwrap_single(group_by.expr)}

        [first | _] = list ->
          {first, Enum.map(list, fn group_by -> unwrap_single(group_by.expr) end)}
      end

    target = expr_to_funcs(target)

    expr = {:{}, [], [joined_expr, target]}

    select = %Ecto.Query.SelectExpr{
      expr: expr,
      file: first_group_by.file,
      line: first_group_by.line
    }

    Map.put(query, :select, select)
  end

  def transform_with_binding(fun, params) do
    {binding_provided, binding, params} = Qh.split_optional_binding(params)

    params = replace_fragments(params)
    params = unwrap_single(params)
    params = maybe_replace_order(fun, params)

    new_params = Qh.Expr.maybe_deep_prefix_binding(binding_provided, params)

    if !binding_provided and params == new_params do
      quote do
        query = Ecto.Query.unquote(fun)(query, unquote(new_params))
      end
    else
      quote do
        query = Ecto.Query.unquote(fun)(query, unquote(binding), unquote(new_params))
      end
    end
  end

  defp maybe_replace_order(:order_by, order) do
    Enum.map(List.wrap(order), fn
      {key, dir}
      when dir in [
             :asc,
             :asc_nulls_last,
             :asc_nulls_first,
             :desc,
             :desc_nulls_last,
             :desc_nulls_first
           ] ->
        {dir, key}

      other ->
        other
    end)
  end

  defp maybe_replace_order(_fun, params) do
    params
  end

  defp replace_fragments(list) do
    case list do
      [q | _] when is_binary(q) ->
        quote do: fragment(unquote_splicing(list))

      list ->
        list
    end
  end

  defp expr_to_funcs(expr) do
    case expr do
      list when is_list(list) -> Enum.map(list, fn sub_expr -> expr_to_funcs(sub_expr) end)
      {fun, arg} -> {fun, [], [{{:., [], [{:&, [], [0]}, arg]}, [], []}]}
      fun when is_atom(fun) -> {fun, [], []}
      expr -> expr
    end
  end

  #

  def has_group_by?(%{group_bys: list}) when length(list) > 0, do: true
  def has_group_by?(_query), do: false

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

  def split_optional_binding(params) do
    if first_param_binding?(params) do
      [binding | params] = params
      {true, binding, params}
    else
      binding = quote do: [t]
      {false, binding, params}
    end
  end

  defp first_param_binding?([maybe_binding | _]), do: is_binding?(maybe_binding)
  defp first_param_binding?(_), do: false

  defp is_binding?(list) do
    is_list(list) &&
      Enum.all?(list, fn
        {key, _, nil} when is_atom(key) -> true
        {alias, {key, _, nil}} when is_atom(alias) and is_atom(key) -> true
        _other -> false
      end)
  end

  def repo(opts \\ []) do
    repo_mod(opts)
  end

  def repo_mod(opts) do
    opts[:repo] || Application.get_env(:qh, :repo) || Module.concat(app_mod(opts), Repo)
  end

  def app_mod(opts) do
    opts[:app_mod] || maybe_camelize(opts[:app]) || Application.get_env(:qh, :app_mod) ||
      maybe_camelize(Application.get_env(:qh, :app))
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
        schema
    end
  end

  defp module_or_raise!(module, schema) do
    if ensure_compiled?(module) do
      module
    else
      raise "unable to find schema for #{inspect(schema)}, #{inspect(module)} does not exist"
    end
  end

  defp ensure_compiled?(module) do
    case Code.ensure_compiled(module) do
      {:module, _} ->
        true

      {:error, _} ->
        false
    end
  end

  defp first_uppercase?(val) do
    String.at(to_string(val), 0) == String.capitalize(String.at(to_string(val), 0))
  end

  defp maybe_camelize(nil), do: nil
  defp maybe_camelize(val), do: Macro.camelize(to_string(val))


  def unwrap_single([item]), do: item
  def unwrap_single(other), do: other

  defp unwrap_nested({{:., _, [left, right]}, opts, children}) do
    parens = if opts[:no_parens], do: false, else: true

    unwrap_nested(left) ++ [{right, [parens: parens], children}]
  end

  defp unwrap_nested({k, _, nil}), do: [k]
  defp unwrap_nested(v), do: [v]
end
