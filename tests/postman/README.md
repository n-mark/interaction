# arch-homework e2e (Postman / newman)

End-to-end smoke-сценарий для helm-чарта `arch-homework`.

## Сценарий

1. **Auth**
   - `POST /register` — создать пользователя.
   - `POST /login` — получить JWT, сохранить в переменную `token`.
   - `POST /profile` — создать профиль пользователя.
2. **Billing account auto-created**
   - `GET /billing` — убедиться, что аккаунт в биллинге создался автоматически (баланс `0.0`).
3. **Top up balance**
   - `PUT /billing` с `{ "amount": 16.90 }` — положить деньги.
   - `GET /billing` — проверить, что баланс стал `16.9`.
4. **Successful order**
   - `POST /order` с `{ "price": 10 }` — заказ, на который хватает денег.
   - `GET /billing` — проверить, что баланс списался до `6.9`.
   - `GET /notifications` — убедиться, что пришло сообщение об успешном заказе (`успешно оформлен`).
5. **Failed order**
   - `POST /order` с `{ "price": 100 }` — заказ, на который не хватает денег.
   - `GET /billing` — проверить, что баланс остался `6.9` (не изменился).
   - `GET /notifications` — убедиться, что пришло сообщение о нехватке средств (`недостаточно средств`).

## Файлы

- `arch-homework.postman_collection.json` — коллекция с тестами и проверками.
- `arch-homework.postman_environment.json` — окружение. `{{baseUrl}} = http://arch.homework` (initial value).
- `run.sh` — обёртка для запуска через `newman` (CLI + JUnit отчёты).
- `newman/report.json`, `newman/report.xml` — артефакты последнего прогона.

## Установка

```bash
# локально в репозитории (рядом с helm-чартом):
cd tests
npm install
```

Глобально:

```bash
npm install -g newman
```

## Запуск

```bash
# из репозитория — ходим на http://arch.homework (default):
./tests/postman/run.sh

# или на другой URL (например, через port-forward):
BASE_URL=http://localhost:8080 ./tests/postman/run.sh
```

В консоль будут выведены: имя запроса, HTTP-метод, URL, request headers/body, response headers/body и результаты ассертов. После прогона лежат:

- `tests/postman/newman/report.json` — полный machine-readable отчёт;
- `tests/postman/newman/report.xml` — JUnit (для CI: GitHub Actions, GitLab CI, Jenkins и т.п.).

## Где используется `{{baseUrl}}`

`{{baseUrl}}` — единственная переменная, описывающая точку входа. Она:
- задаётся в `arch-homework.postman_environment.json` со значением `http://arch.homework`;
- используется во всех 12 запросах коллекции как хост URL (см. поле `url.raw` в каждом запросе);
- может быть переопределена через переменную окружения `BASE_URL` при запуске скрипта.

## Где живёт токен

JWT, полученный из `/login`, сохраняется в collection variable `token` тестом в `Login`:

```js
var json = pm.response.json();
pm.collectionVariables.set('token', json.token);
```

Все защищённые эндпоинты (`/profile`, `/billing`, `/order`, `/notifications`) автоматически подставляют `Authorization: Bearer {{token}}` в заголовке.

## Ожидаемые коды ответов

| Шаг | URL | Метод | Ожидаемый код |
|---|---|---|---|
| Register | `/register` | POST | 200-299 |
| Login | `/login` | POST | 200-299 |
| Create profile | `/profile` | POST | 200-299 |
| Get billing | `/billing` | GET | 200-299 |
| Top up | `/billing` | PUT | 200-299 |
| Order (ok) | `/order` | POST | 200-299 |
| Order (fail) | `/order` | POST | 200-499 (бизнес-ошибка, не 5xx) |

## CI-пример (GitHub Actions)

```yaml
- name: e2e
  run: |
    cd tests
    npm ci
    ./postman/run.sh
- name: publish junit
  if: always()
  uses: mikepenz/action-junit-report@v4
  with:
    report_paths: tests/postman/newman/report.xml
```
