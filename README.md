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
    participant P as profile-service
    participant O as order-service
    participant B as billing-service
    participant I as items-serivce
    participant N as notification-service
    %% box external
    %% participant E as ext-email
    %% end

    C->>AG: POST /order
    Note over C: POST http(s)://arch.homework/order <br/> -H "Authorization: Bearer $TOKEN"  <br/> -H 'Content-Type: application/json' <br/> -d '{"order_content":[]item}'
    %% activate P
    AG->>A: GET /validate
    A-->>AG: 200, X-User-Id: {{user_id}}
    AG->>O: POST /order (X-User-Id: {{user_id}}), body: {"order_content":[]item}
    O->>O: put order into database <br/> with status "PENDING"
    O-->>AG: 201 order created
    AG-->>C: 201 created
    O->>I: POST /item/price
    Note over O: POST http://items-service/item/price <br/> body: []item_id
    I-->>O: 200 OK
    Note over I: response body: [{"item_id":, "price"}, ...]
    O->>O: calculate total price

    O->>B: POST /hold
    Note over O: POST http://billing-service/hold <br/> Headers: "X-User-Id: {{user_id}}" <br/> Body: {"amount": {{total_price}} }
    alt денег достаточно
        B-->>O: 200 OK
        O->>O: update DB order status to "SUCCESSFULLY_PAID"
    else недостаточно средств
        B->>O: 402 Payment Required
        O->>O: update DB order status to "PAYMENT_FAILED"
    end
    O->>N: POST /notification
    Note over O: POST http://notification-service/notify <br/> Headers: "X-User-Id: {{user_id}}" <br/> body: {"type", "message"}
    %% P->>B: POST /create
    %% activate B
    %%Note over P: POST http://billing-service/account <br/> {"user_id": 1}
    %%B->>P: 201 created
    %% deactivate B
    %%P->>C: 201 created
    %% deactivate P


%% Note over P: Holds JWT of user2 (sub=2).<br/>Tries to read/write user1's profile.
```


## Вариант 2 - событийное взаимодействие с использованием брокера сообщений для нотификаций (уведомлений)
### Создание заказа
```mermaid
sequenceDiagram
    autonumber
    actor C as Client
    participant AG as api-gateway
    participant A as auth-service
    participant P as profile-service
    participant O as order-service
    participant B as billing-service
    participant I as items-serivce
    participant broker@{ "type" : "queue" }
    participant N as notification-service
    %% box external
    %% participant E as ext-email
    %% end

    C->>AG: POST /order
    Note over C: POST http(s)://arch.homework/order <br/> -H "Authorization: Bearer $TOKEN"  <br/> -H 'Content-Type: application/json' <br/> -d '{"order_content":[]item}'
    %% activate P
    AG->>A: GET /validate
    A-->>AG: 200, X-User-Id: {{user_id}}
    AG->>O: POST /order (X-User-Id: {{user_id}}), body: {"order_content":[]item}
    O->>O: put order into database <br/> with status "PENDING"
    O-->>AG: 201 order created
    AG-->>C: 201 created
    O->>I: POST /item/price
    Note over O: POST http://items-service/item/price <br/> body: []item_id
    I-->>O: 200 OK
    Note over I: response body: [{"item_id":, "price"}, ...]
    O->>O: calculate total price

    O->>B: POST /hold
    Note over O: POST http://billing-service/hold <br/> Headers: "X-User-Id: {{user_id}}" <br/> Body: {"amount": {{total_price}} }
    alt денег достаточно
        B-->>O: 200 OK
        O->>O: update DB order status to "SUCCESSFULLY_PAID"
    else недостаточно средств
        B->>O: 402 Payment Required
        O->>O: update DB order status to "PAYMENT_FAILED"
    end
    O-->>broker: PRODUCE to notification queue/topic
        Note over O: MESSAGE <br/> {"user_id", "order_id", "type", "message"}
    loop
    N-->>broker: CONSUME from notification queue/topic
    end
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