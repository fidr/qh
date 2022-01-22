defmodule QTest do
  use Qh.DataCase, async: true

  use Qh

  setup do
    bob = QTest.Repo.insert!(%QTest.User{name: "Bob", age: 22, nicknames: ["Bobi", "Bobby"]})
    anna = QTest.Repo.insert!(%QTest.User{name: "Anna", age: 21, nicknames: ["Ann"]})
    _james = QTest.Repo.insert!(%QTest.User{name: "James", age: 65})
    _john = QTest.Repo.insert!(%QTest.User{name: "John", age: 40})

    QTest.Repo.insert!(%QTest.Message{user_id: bob.id, message: "Message to bob 1", likes: 5})
    QTest.Repo.insert!(%QTest.Message{user_id: bob.id, message: "Message to bob 2", likes: 4})
    QTest.Repo.insert!(%QTest.Message{user_id: anna.id, message: "Message to anna 1", likes: 2})
    QTest.Repo.insert!(%QTest.Message{user_id: anna.id, message: "Message to anna 2", likes: 3})
    QTest.Repo.insert!(%QTest.Message{user_id: anna.id, message: "Message to anna 3", likes: 2})

    :ok
  end

  test "first" do
    assert %QTest.User{name: "Bob"} = q(User.first())
  end

  test "last" do
    assert %QTest.User{name: "John"} = q(User.last())
  end

  test "first n" do
    assert [%QTest.User{name: "Bob"}, %QTest.User{name: "Anna"}] = q(User.first(2))
  end

  test "last n" do
    assert [%QTest.User{name: "James"}, %QTest.User{name: "John"}] = q(User.last(2))
  end

  test "count" do
    assert 4 = q(User.count())
  end

  test "select" do
    assert ["Bob", "Anna", "James", "John"] = q(User.select(name).all())
  end

  test "select multiple" do
    assert [["Bob", 22], ["Anna", 21], ["James", 65], ["John", 40]] =
             q(User.select(name, age).all())
  end

  test "select custom struct" do
    assert [%{name: "Bob"}, %{name: "Anna"}, %{name: "James"}, %{name: "John"}] =
             q(User.select(%{name: name}).all())
  end

  test "select with binding" do
    assert ["Bob", "Anna", "James", "John"] = q(User.select([u], u.name).all())
  end

  test "select merge" do
    assert [
             %{age: 22, name: "Bob"},
             %{age: 21, name: "Anna"},
             %{age: 65, name: "James"},
             %{age: 40, name: "John"}
           ] ==
             q(
               User.order(id).select(%{}).select_merge(%{name: name}).select_merge(%{age: age}).all
             )
  end

  test "where" do
    assert 1 = q(User.where(age > 25 and age < 50).count)
  end

  test "where with binding" do
    assert 1 = q(User.where([u], u.age > 25 and u.age < 50).count)
  end

  test "where or" do
    assert 2 = q(User.where(name == "Bob" or name == "Anna").count)
  end

  test "where nested" do
    assert 2 =
             q(
               User.where(age < 50 and (name == "Bob" or name == "Anna" or name == "James")).count
             )
  end

  test "pinned where" do
    name = "Bob"
    assert 1 = q(User.where(name: ^name).count)
  end

  test "keyword where" do
    assert 1 = q(User.where(age: 22, name: "Bob").count)
  end

  test "fragment where" do
    assert 2 = q(User.where("nicknames && ?", ["Bobi", "Ann"]).count)
  end

  test "fragment where 2" do
    assert 2 = q(User.where("name = ANY(?)", ["Bob", "Anna"]).count)
  end

  test "fragment where with field" do
    assert 1 = q(User.where("? && ?", nicknames, ["Bobi", "Bobby"]).count)
  end

  test "having" do
    assert [5] =
             q(User.group_by(name).select("length(?)", name).having("length(?) > ?", name, 4).all)
  end

  test "find_by" do
    assert %{name: "Bob"} = q(User.find_by(name: "Bob"))
  end

  test "find_by non existing" do
    assert nil == q(User.find_by(name: "Foo"))
  end

  test "find_by complex" do
    assert %{name: "John"} = q(User.find_by(age > 25 and age < 50))
  end

  test "find_by fragment" do
    assert %{name: "James"} = q(User.find_by("age = ?", 65))
  end

  test "order" do
    assert %{age: 21} = q(User.order(age).first)
  end

  test "order desc" do
    assert %{age: 65} = q(User.order(age: :desc).first)
  end

  test "order multiple" do
    assert %{age: 65} = q(User.order(age: :desc, name: :asc).first)
  end

  test "order by fragment" do
    assert %{name: "Anna"} = q(User.order("lower(?)", name).first)
  end

  test "group_by count" do
    assert [{3, 1}, {5, 1}, {4, 2}] = q(User.group_by("length(name)").count)
  end

  test "group_by avg" do
    assert [{3, avg} | _] = q(User.group_by("length(name)").avg(age))
    assert Decimal.equal?(avg, Decimal.from_float(22.0))
  end

  test "aggr multiple" do
    assert [{3, {1, 22}}, {5, {1, 65}} | _] =
             q(User.group_by("length(name)").aggr({count(), min(age)}))
  end

  test "aggr without group_by" do
    assert {4, 21} = q(User.aggr({count(), min(age)}))
  end

  test "limit" do
    assert 2 = length(q(User.limit(2).all))
  end

  test "query" do
    assert %Ecto.Query{} = q(User.query())
  end

  test "preload" do
    assert %{messages: messages} = q(User.preload(:messages).first)
    assert length(messages) == 2
  end

  test "preload custom query" do
    messages_query = q(Message.order(likes))

    assert %{messages: [%{likes: 4}, %{likes: 5}]} =
             q(User.preload(messages: ^messages_query).first)
  end

  test "preload custom query direct" do
    assert %{messages: [%{likes: 4}, %{likes: 5}]} =
             q(User.preload(messages: ^q(Message.order(likes))).first)
  end

  test "reverse_order" do
    assert [%{name: "John"} | _] = q(User.order(id).reverse_order.all)
  end

  test "except_all" do
    oldest_2 = q(User.order(age: :desc).limit(2))

    assert [%{name: "Bob"}, %{name: "Anna"}] =
             q(User.except_all(^oldest_2).all) |> Enum.sort_by(fn u -> u.id end)
  end

  test "except" do
    oldest_2 = q(User.order(age: :desc).limit(2))

    assert [%{name: "Bob"}, %{name: "Anna"}] =
             q(User.except(^oldest_2).all) |> Enum.sort_by(fn u -> u.id end)
  end

  test "exclude" do
    assert %{name: "Bob"} = q(User.select(age).exclude(:select).first)
  end

  test "intersect" do
    not_bob = q(User.where(name != "Bob"))
    not_anna = q(User.where(name != "Anna"))

    assert [%{name: "James"}, %{name: "John"}] =
             q(not_bob.intersect(^not_anna).all) |> Enum.sort_by(fn u -> u.id end)
  end

  test "intersect all" do
    not_bob = q(User.where(name != "Bob"))
    not_anna = q(User.where(name != "Anna"))

    assert [%{name: "James"}, %{name: "John"}] =
             q(not_bob.intersect_all(^not_anna).all) |> Enum.sort_by(fn u -> u.id end)
  end

  test "exists?" do
    assert true == q(User.where(name: "Bob").exists?)
    assert false == q(User.where(name: "Noone").exists?)
  end

  test "one" do
    assert %{name: "Bob"} = q(User.where(name: "Bob").one)
  end

  test "one returns nil for empty" do
    assert nil == q(User.where(name: "Noone").one)
  end

  test "one raises for multiple" do
    assert_raise Ecto.MultipleResultsError, fn -> q(User.one()) end
  end

  test "stream" do
    assert %Stream{} = q(User.stream())
  end

  test "join" do
    assert 2 = q(User.distinct(id).join(:messages).all) |> length()
  end

  test "custom join" do
    assert 2 =
             q(User.distinct(id).join([u], m in assoc(u, :messages), on: u.id == m.user_id).all)
             |> length()
  end

  # modify

  test "new" do
    assert %QTest.User{} = q(User.new())
  end

  test "new with params" do
    assert %QTest.User{name: "Alice", age: 25} = q(User.new(name: "Alice", age: 25))
  end

  test "save new" do
    user = q(User.new(name: "Alice", age: 25))
    assert {:ok, _user} = Qh.Repo.save(user)
    assert 5 == q(User.count())
  end

  test "save existing" do
    user = q(User.first())
    assert {:ok, _user} = Qh.Repo.assign(user, age: 23) |> Qh.Repo.save()
    assert q(User.find_by(name: ^user.name)).age == 23
  end

  test "save validation failure" do
    assert {:error, [name: {"can't be blank", [validation: :required]}]} =
             Qh.Repo.save(%QTest.User{})
  end

  test "update" do
    user = q(User.first())
    assert {:ok, _user} = Qh.Repo.update(user, age: 23)
    assert q(User.find_by(name: ^user.name)).age == 23
  end

  test "update non existing" do
    assert_raise Ecto.NoPrimaryKeyValueError, fn ->
      Qh.Repo.update(%QTest.User{name: "Test"}, age: 23)
    end
  end

  test "delete!" do
    user = q(User.first())
    Qh.Repo.delete!(user)
    assert 3 == q(User.count())
  end
end
