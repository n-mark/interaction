#!/usr/bin/env bash
# Запуск e2e-сценария через newman.
#
# Использование:
#   ./tests/postman/run.sh
#
# Опционально:
#   BASE_URL=https://arch.example.com ./tests/postman/run.sh
#
# Требования:
#   - newman (https://www.npmjs.com/package/newman)
#       npm install -g newman
#   - либо локально в проекте: npm i -D newman

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTION="${DIR}/arch-homework.postman_collection.json"
ENV_FILE="${DIR}/arch-homework.postman_environment.json"

if ! command -v newman >/dev/null 2>&1; then
  if [ -f "${DIR}/../../node_modules/.bin/newman" ]; then
    NEWMAN="${DIR}/../../node_modules/.bin/newman"
  else
    echo "newman not found. Install: npm install -g newman" >&2
    exit 1
  fi
else
  NEWMAN="newman"
fi

# По умолчанию ходим на http://arch.homework, как требует задание.
# Можно переопределить переменную окружения baseUrl через BASE_URL.
EXTRA_ARGS=()
if [ -n "${BASE_URL:-}" ]; then
  EXTRA_ARGS+=(--env-var "baseUrl=${BASE_URL}")
fi
# На случай пустого EXTRA_ARGS и `set -u` — раскрываем как пустую строку.
EXTRA_ARGS_STR="${EXTRA_ARGS[*]:-}"

# Запуск:
#   --reporters cli,junit  — CLI печатает в консоль и request и response body;
#                            junit нужен для CI (tests/postman/newman/report.xml)
#   --reporter-cli-export  — сохранить полный отчёт в JSON
#   --reporter-junit-export — сохранить junit для CI
#   --color on            — раскрашивает (если tty)
#   --bail                — остановить на первом упавшем тесте (закомментируй если нужно прогнать всё)
exec "${NEWMAN}" run "${COLLECTION}" \
  --environment "${ENV_FILE}" \
  ${EXTRA_ARGS_STR} \
  --reporters cli,json,junit \
  --reporter-json-export "${DIR}/newman/report.json" \
  --reporter-junit-export "${DIR}/newman/report.xml" \
  --color on
