Created app 'subbu-dev1' in organization 'personal'

Admin URL: https://fly.io/apps/subbu-dev1
Hostname: subbu-dev1.fly.dev
Set secrets on subbu-dev1: SECRET_KEY_BASE
Creating postgres cluster in organization personal
Creating app...
Setting secrets on app subbu-dev1-db...
Provisioning 1 of 1 machines with image flyio/postgres-flex:17.2@sha256:77a24a931bf5862878fb6b53c1e62fd914beb69e7864a56b0f17d2bd069f1529
Waiting for machine to start...
Machine e8293e1c19e478 is created
==> Monitoring health checks
  Waiting for e8293e1c19e478 to become healthy (started, 3/3)

Postgres cluster subbu-dev1-db created
  Username:    postgres
  Password:    SDUeBRnRyVm6gTc
  Hostname:    subbu-dev1-db.internal
  Flycast:     fdaa:9:752:0:1::8
  Proxy port:  5432
  Postgres port:  5433
  Connection string: postgres://postgres:SDUeBRnRyVm6gTc@subbu-dev1-db.flycast:5432

Save your credentials in a secure place -- you won't be able to see them again!

Connect to postgres
Any app within the vXecute organization can connect to this Postgres using the above connection string

Now that you've set up Postgres, here's what you need to understand: https://fly.io/docs/postgres/getting-started/what-you-should-know/
Checking for existing attachments
Registering attachment
Creating database
Creating user

Postgres cluster subbu-dev1-db is now attached to subbu-dev1
The following secret was added to subbu-dev1:
  DATABASE_URL=postgres://subbu_dev1:Fd662IcMrhjZjTB@subbu-dev1-db.flycast:5432/subbu_dev1?sslmode=disable
Postgres cluster subbu-dev1-db is now attached to subbu-dev1

Fluxon license key
- Add `FLUXON_LICENSE_KEY` to secrets.
- Deploy with build secret: `fly deploy --build-secret FLUXON_LICENSE_KEY=$FLUXON_LICENSE_KEY`

IPv6 for Postgres
- Set `ECTO_IPV6=true` for Fly to resolve `.internal`/`.flycast` hosts.
