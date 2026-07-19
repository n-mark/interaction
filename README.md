# Проектирование взаимодействия сервисов при создании заказа

## Спецификации API

### OpenAPI (HTTP)
| Сервис | Файл |
|--------|------|
| auth-service         | [auth-openapi-spec.yaml](./openapi/auth-openapi-spec.yaml) |
| profile-service      | [profile-openapi-spec.yaml](./openapi/profile-openapi-spec.yaml) |
| order-service        | [order-openapi-spec.yaml](./openapi/order-openapi-spec.yaml) |
| billing-service      | [billing-openapi-spec.yaml](./openapi/billing-openapi-spec.yaml) |
| notification-service | [notification-openapi-spec.yaml](./openapi/notification-openapi-spec.yaml) |

### AsyncAPI (брокер сообщений)
| Сервис | Файл |
|--------|------|
| profile-service      | [profile-async-api-spec.yaml](./async-api/profile-async-api-spec.yaml) |
| order-service        | [order-async-api-spec.yaml](./async-api/order-async-api-spec.yaml) |
| billing-service      | [billing-async-api-spec.yaml](./async-api/billing-async-api-spec.yaml) |
| notification-service | [notification-async-api-spec.yaml](./async-api/notification-async-api-spec.yaml) |

---

## Вариант 1 - только HTTP взаимодействие

### Создание профиля
```mermaid
sequenceDiagram
    autonumber
    actor C as Client
    participant AG as api-gateway
    participant A as auth-service
    participant P as profile-service
    %% participant O as order-service
    participant B as billing-service
    %% participant N as notification-service
    %% box external
    %% participant E as ext-email
    %% end

    C->>AG: PUT /profile
    Note over C: PUT http(s)://arch.homework/profile <br/> -H "Authorization: Bearer $TOKEN"  <br/> -H 'Content-Type: application/json' <br/> -d '{"name":"Alice","surname":"Doe","city":"Berlin","bio":"hi"}'
    %% activate P
    AG->>A: GET /validate
    A-->>AG: 200, X-User-Id: {{user_id}}
    AG->>P: PUT /profile (X-User-Id: {{user_id}})
    P->>B: POST /create
    %% activate B
    Note over P: POST http://billing-service/account <br/> {"user_id": 1}
    B->>P: 201 created
    %% deactivate B
    P->>C: 201 created
    %% deactivate P
```

### Создание заказа
```mermaid
sequenceDiagram
    autonumber
    actor C as Client
    participant AG as api-gateway
    participant A as auth-service
    participant O as order-service
    participant B as billing-service
    participant N as notification-service

    C->>AG: POST /order
    Note over C: POST http(s)://arch.homework/order <br/> -H "Authorization: Bearer $TOKEN"  <br/> -H 'Content-Type: application/json' <br/> -d '{"total_price": 100}'
    AG->>A: GET /validate
    A-->>AG: 200, X-User-Id: {{user_id}}
    AG->>O: POST /order (X-User-Id: {{user_id}}), body: {"total_price": 100}
    O->>O: put order into database <br/> with status "PENDING"
    O-->>AG: 201 order created
    AG-->>C: 201 created

    O->>B: POST /withdraw
    Note over O: POST http://billing-service/withdraw <br/> Headers: "X-User-Id: {{user_id}}" <br/> Body: {"amount": {{total_price}}, "order_id": {{order_id}} }
    alt денег достаточно
        B-->>O: 200 OK
        O->>O: update DB order status to "SUCCESSFULLY_PAID"
        O->>N: POST /notify
        Note over O: body: {"type":"ORDER_PAID", "message":"письмо счастья"}
    else недостаточно средств
        B-->>O: 402 Payment Required
        O->>O: update DB order status to "PAYMENT_FAILED"
        O->>N: POST /notify
        Note over O: body: {"type":"ORDER_PAYMENT_FAILED", "message":"письмо горя"}
    end
```


## Вариант 2 - событийное взаимодействие с использованием брокера сообщений для нотификаций (уведомлений)
### Создание заказа
```mermaid
sequenceDiagram
    autonumber
    actor C as Client
    participant AG as api-gateway
    participant A as auth-service
    participant O as order-service
    participant B as billing-service
    participant broker@{ "type" : "queue" }
    participant N as notification-service

    C->>AG: POST /order
    Note over C: POST http(s)://arch.homework/order <br/> -H "Authorization: Bearer $TOKEN"  <br/> -H 'Content-Type: application/json' <br/> -d '{"total_price": 100}'
    AG->>A: GET /validate
    A-->>AG: 200, X-User-Id: {{user_id}}
    AG->>O: POST /order (X-User-Id: {{user_id}}), body: {"total_price": 100}
    O->>O: put order into database <br/> with status "PENDING"
    O-->>AG: 201 order created
    AG-->>C: 201 created

    O->>B: POST /withdraw
    Note over O: POST http://billing-service/withdraw <br/> Headers: "X-User-Id: {{user_id}}" <br/> Body: {"amount": {{total_price}}, "order_id": {{order_id}} }
    alt денег достаточно
        B-->>O: 200 OK
        O->>O: update DB order status to "SUCCESSFULLY_PAID"
    else недостаточно средств
        B-->>O: 402 Payment Required
        O->>O: update DB order status to "PAYMENT_FAILED"
    end
    O-->>broker: PRODUCE to notification queue/topic
        Note over O: MESSAGE <br/> {"user_id", "order_id", "type", "message"}
    loop
    N-->>broker: CONSUME from notification queue/topic
    end
    N->>N: save notification into database
```


## Вариант 3 - Event Collaboration cтиль взаимодействия с использованием брокера сообщений

### Создание профиля
```mermaid
sequenceDiagram
    autonumber
    actor C as Client
    participant AG as api-gateway 
    participant A as auth-service
    participant P as profile-service
    %% participant O as order-service
    participant B as billing-service
    participant broker@{ "type" : "queue" }
    %% participant N as notification-service
    %% box external
    %% participant E as ext-email
    %% end

    C->>AG: PUT /profile
    Note over C: PUT http(s)://arch.homework/profile <br/> -H "Authorization: Bearer $TOKEN"  <br/> -H 'Content-Type: application/json' <br/> -d '{"name":"Alice","surname":"Doe","city":"Berlin","bio":"hi"}'
    %% activate P
    AG->>A: GET /validate
    A-->>AG: 200, X-User-Id: {{user_id}}
    AG->>P: PUT /profile (X-User-Id: {{user_id}})
    P->>P: put into database with <br/> 'BILLIING_ACCOUNT_CREATE_PENDING' status
    P->>AG: 201 created
    AG->>C: 201 created
    P-->>broker: PRODUCE to profile.*
    Note over P: MESSAGE <br/> {"eventid", "user_id", "event_type"="profile.created"}
    loop
    B-->>broker: CONSUME from profile.*
    end
    B->>B: check eventid for idempotency <br/> check user_id constraint <br/> create new billing account
    B-->>broker: PRODUCE to billing.*
    Note over B: MESSAGE <br/> {"eventid", "user_id", "event_type"="billing.account_created"}
    loop
    P-->>broker: CONSUME from billing.*
    end
    P->>P: check eventid for idempotency <br/> update profile status to "CREATED"
```

### Создание заказа
```mermaid
   sequenceDiagram
   autonumber
   actor C as Client
   participant AG as api-gateway
   participant A as auth-service
   participant O as order-service
   participant B as billing-service
   participant N as notification-service
   participant broker@{ "type" : "queue" }

   C->>AG: POST /order <br/> Authorization bearer token <br/> body: {"total_price"}
   AG->>A: validate token
   A->>AG: return user id <br/> in response headers
   AG->>O: POST /order <br/> X-User-Id : user id <br/> body: {"total_price"}
   O->>O: insert into database <br/> with "PAYMENT_PENDING" status
   O->>AG: 201 created
   AG->>C: 201 created
   O-->>broker: PRODUCE order.created <br/> {"eventid", "userid", "orderid", "total"}
   loop
   B-->>broker: CONSUME order.created
   end
   B->>B: check eventid idempotency <br/> check if enough money <br/> withdraw or report insufficent funds 
   B-->>broker: PRODUCE billing.processed <br/> {"eventid", "userid", "orderid", "result"}
   loop
   O-->>broker: CONSUME billing.processed
   end
   O->>O: check result <br/> update to "SUCCESSFULLY PAID" <br/> if result is "SUCCESS" <br/> update to "PAYMENT_REQUIRED" <br/> if result is "INSUFFICENT_FUNDS"
   O-->>broker: PRODUCE order.updated <br/> {"eventid", "userid", "orderid", "event_description", "message", "notification_type"}
   loop
   N-->>broker: CONSUME order.updated
   end
   N->>N: process notification
```

---

## Наиболее адекватный вариант для данной задачи

**Выбран: Вариант 3 — Event Collaboration через брокер сообщений.**

### Почему не вариант 1 (HTTP-only)
- Жёсткая связность: `order-service` должен знать про `billing` и `notification` и быть доступным к каждому из них в момент обработки заказа.
- Нет естественной устойчивости к временной недоступности контрагентов — нужны retry/circuit-breaker в каждом вызове.
- Сложно добавлять новых подписчиков на факт создания/оплаты заказа — каждый такой потребитель требует изменения кода `order-service`.

### Почему не вариант 2 (HTTP + брокер только для нотификаций)
- Гибридная модель: часть связей синхронная, часть асинхронная — сложнее в эксплуатации и отладке.
- Основной flow создания заказа всё ещё синхронный — если `billing` недоступен, заказ не создаётся.
- Существенные архитектурные проблемы варианта 1 остаются.

### Почему вариант 3
- **Слабая связность:** `order-service` публикует факт создания заказа и не знает, кто его обработает.
- **Устойчивость к сбоям:** кратковременная недоступность `billing` или `notification` не ломает создание заказа — сообщения остаются в брокере.
- **Ответ клиенту быстрый:** 201 возвращается сразу после сохранения в БД со статусом `PAYMENT_PENDING`.
- **Расширяемость:** новые потребители (аналитика, склад, CRM) подключаются к `order.created`/`order.updated` без изменения `order-service`.
- **Единообразный стиль:** тот же подход используется и при создании профиля (см. выше), что упрощает эксплуатацию.

### На что обратить внимание при реализации
- **Идемпотентность** потребителей (проверка `eventid`) — брокер может доставлять сообщения повторно (at-least-once).
- **Transactional outbox** в продюсерах чтобы гарантировать: запись в БД и отправка в брокер — атомарны.
- **Eventual consistency:** клиент видит заказ с `PAYMENT_PENDING` и получает финальный статус через нотификацию или повторным GET.
- **Schema Registry / версионирование событий** — контракты `order.*`, `billing.*`, `profile.*` зафиксированы в AsyncAPI спецификациях выше.


## Реализация

### Сервис заказов

- [`https://github.com/n-mark/order-svc`](https://github.com/n-mark/order-svc)
- [`dockerhub: mblkuta/ordersvc:0.1.0`](https://hub.docker.com/repository/docker/mblkuta/ordersvc/tags/0.1.0/)


### Сервис биллинга

- [`https://github.com/n-mark/billing-svc`](https://github.com/n-mark/billing-svc)
- [`dockerhub: mblkuta/billingsvc:0.1.2`](https://hub.docker.com/repository/docker/mblkuta/billingsvc/tags/0.1.2/)

### Сервис нотификаций

- [`https://github.com/n-mark/notificationsvc`](https://github.com/n-mark/notificationsvc)
- [`dockerhub: mblkuta/notificationsvc:0.1.0`](https://hub.docker.com/repository/docker/mblkuta/notificationsvc/tags/0.1.0/)

### Сервис профилей (новая версия, вынесен в отдельный репозиторий)

- [`https://github.com/n-mark/profilesvc`](https://github.com/n-mark/profilesvc)
- [`dockerhub: mblkuta/profile-service:0.2.0`](https://hub.docker.com/repository/docker/mblkuta/profile-service/tags/0.2.0/)

В качестве брокера сообщений используется RabbitMQ. Однако за счет использования интерфейсов в сервисах в дальшнейшем возможно сделать реализации и для других брокеров сообщений

## Helm-чарт

Для установки приложения в kubernetes кластер выполните команду (namespace: arch-hw)

```bash
helm install arch-hw ./helm/arch-homework
```

## Тесты 

postman-скрипт доступен в директории `tests/postman`
Описание и инструкция по запуску находятся в [`tests/postman/README.md`](tests/postman/README.md)