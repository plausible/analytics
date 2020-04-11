# #!/bin/sh
set -e
set -x


# Ensure the app's dependencies are installed
mix deps.get

# Install Javascript libraries
echo "\nInstalling Javascript dependencies..."
cd assets && npm install
cd ..

# Wait for Postgres to become available.
until psql -h postgres -U "postgres" -c '\q' 2>/dev/null; do
   >&2 echo "Postgres is unavailable - sleeping"
   sleep 1
done

echo "\nPostgres is available: continuing with database setup..."

# # Potentially Set up the database
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate

echo "\n Launching Phoenix web server..."

# Start the phoenix web server
MIX_ENV=dev mix phx.server
