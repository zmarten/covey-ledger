#!/usr/bin/env bash
# Runs the compliance tests against a throwaway database on a LOCAL Postgres.
# Usage: supabase/tests/run.sh [number of migrations to apply, default all]
# Connection comes from the usual PG* variables (PGHOST, PGPORT, PGUSER).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
db="covey_test_$$"
limit="${1:-999}"
q() { psql -X -q -v ON_ERROR_STOP=1 -d "$db" "$@"; }

createdb "$db"
trap 'dropdb --if-exists "$db"' EXIT

q -f "$here/00_local_supabase_stub.sql"
n=0
for m in "$here"/../migrations/*.sql; do
  n=$((n + 1)); [ "$n" -le "$limit" ] || break
  q -f "$m" >/dev/null
done
q -f "$here/compliance_test.sql" >/dev/null

# Two sessions log a full daily limit at the same moment; one must lose.
race() {
  psql -X -q -d "$db" >/dev/null 2>&1 <<SQL || true
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
SET ROLE authenticated;
BEGIN;
SELECT t.harvest('OR', 3, '2026-11-01');
SELECT pg_sleep(1);
COMMIT;
SQL
}
race & race & wait
q -c "INSERT INTO t.results (label, expected, got, detail)
      SELECT 'race: two simultaneous entries at the daily limit', 'blocked',
             CASE WHEN sum(quantity) > 3 THEN 'allowed' ELSE 'blocked' END,
             sum(quantity) || ' birds logged against a limit of 3'
      FROM harvest_entries WHERE state_id = t.st('OR')"

q -At -F ' | ' -c "SELECT CASE WHEN expected = got THEN 'PASS' ELSE 'FAIL' END, label,
                          CASE WHEN expected = got THEN '' ELSE 'expected ' || expected || ', was ' || got END
                   FROM t.results ORDER BY n"
fails="$(q -At -c "SELECT count(*) FROM t.results WHERE expected <> got")"
total="$(q -At -c "SELECT count(*) FROM t.results")"
echo "$((total - fails)) of $total passed"
[ "$fails" -eq 0 ]
