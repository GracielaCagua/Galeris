-- Crea el usuario y la base de desarrollo en un PostgreSQL ya instalado.
-- Se puede ejecutar varias veces. La contraseña es solo para desarrollo local.
--   psql -U postgres -f backend/scripts/setup_postgres.sql
SELECT 'CREATE ROLE galeris LOGIN PASSWORD ''galeris'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'galeris')
\gexec

SELECT 'CREATE DATABASE galeris OWNER galeris'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'galeris')
\gexec
