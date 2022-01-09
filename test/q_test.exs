defmodule QTest do
  use Qh.DataCase, async: true

  use Qh

  setup do
    QTest.Repo.insert!(%QTest.User{name: "Bob", age: 22, nicknames: ["Bobi", "Bobby"]})
    QTest.Repo.insert!(%QTest.User{name: "Anna", age: 21, nicknames: ["Ann"]})
    QTest.Repo.insert!(%QTest.User{name: "James", age: 65})
    QTest.Repo.insert!(%QTest.User{name: "John", age: 40})

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
    assert ["Bob", "Anna", "James", "John"] = q(User.select(name))
  end

  test "select multiple" do
    assert [["Bob", 22], ["Anna", 21], ["James", 65], ["John", 40]] = q(User.select(name, age))
  end

  test "select custom struct" do
    assert [%{name: "Bob"}, %{name: "Anna"}, %{name: "James"}, %{name: "John"}] = q(User.select(%{name: name}))
  end

  test "where" do
    assert 1 = q(User.where(age > 25 and age < 50).count)
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

  test "new" do
    assert %QTest.User{} = q(User.new())
  end

  test "new with params" do
    assert %QTest.User{name: "Alice", age: 25} = q(User.new(name: "Alice", age: 25))
  end

  test "save new" do
    user = q(User.new(name: "Alice", age: 25))
    assert {:ok, _user} = Qh.save(user)
    assert 5 == q(User.count())
  end

  test "save existing" do
    user = q(User.first())
    assert {:ok, _user} = Qh.assign(user, age: 23) |> Qh.save()
    assert q(User.find_by(name: ^user.name)).age == 23
  end

  test "save validation failure" do
    assert {:error, [name: {"can't be blank", [validation: :required]}]} = Qh.save(%QTest.User{})
  end

  test "update" do
    user = q(User.first())
    assert {:ok, _user} = Qh.update(user, age: 23)
    assert q(User.find_by(name: ^user.name)).age == 23
  end

  test "update non existing" do
    assert_raise Ecto.NoPrimaryKeyValueError, fn ->
      Qh.update(%QTest.User{name: "Test"}, age: 23)
    end
  end

  test "delete!" do
    user = q(User.first())
    Qh.delete!(user)
    assert 3 == q(User.count())
  end
end
