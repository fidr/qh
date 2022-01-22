ExUnit.start()

{:ok, _, _} =
  Ecto.Migrator.with_repo(QTest.Repo, fn repo ->
    Ecto.Migrator.down(repo, 2, QTest.Repo.Migrations.SetupMessages)
    Ecto.Migrator.down(repo, 1, QTest.Repo.Migrations.SetupUsers)
    Ecto.Migrator.up(repo, 1, QTest.Repo.Migrations.SetupUsers)
    Ecto.Migrator.up(repo, 2, QTest.Repo.Migrations.SetupMessages)
  end)

QTest.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(QTest.Repo, :manual)
