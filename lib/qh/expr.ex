defmodule Qh.Expr do
  def maybe_deep_prefix_binding(skip_cond, tree) do
    if skip_cond do
      tree
    else
      deep_prefix_binding(tree)
    end
  end

  def deep_prefix_binding(tree, prefix \\ {:t, [], nil}) do
    conditional_prewalk(tree, fn
      {:^, _, _} = node ->
        {false, node}

      {field, _, nil} ->
        {false, {{:., [], [prefix, field]}, [no_parens: true], []}}

      node ->
        {true, node}
    end)
  end

  def conditional_prewalk(tree, fun) do
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