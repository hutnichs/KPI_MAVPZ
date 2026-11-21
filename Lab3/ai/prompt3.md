Питання:
Виправ SC-07, щоб гілка 409 писала в SecLog і була відокремлена від дубля та від очікуваного переходу. Додай підпис verifyHmacSha256 до всіх діаграм callback та refundCallback де потрібні.
В SC-09 додай транзакцію, блокування і гілку нестачі товару за REQ-004. Прибери подвійний deactivate DB в SC-15. А також поправ невідповідності які сам знайдеш.

Відповідь:

Менші правки

SC-15 тепер питає сторінку через PS/БД, а не показує повідомлення «з повітря».
SecLog повертає просто logged, а «дані не змінено» винесено в Note. Подія скрізь називається logSecurityEvent.
Вгорі додано примітку, що P1/P2/P9999 — умовні позначки pay_id (тип int).
Скрізь HTTP 200 OK іде до refundPayment (NFR-002), а в SC-01 додано примітку про повтор транзакції до 3 разів (NFR-010).
SC-06: перевіряється Payment.date, а markPaymentTimeout спрацьовує лише якщо платіж досі pending.
Планувальник у SC-06 тепер працює напряму з базою даних, як описано в spec.md: він сам знаходить прострочені платежі і сам їх позначає як failed з причиною timeout. Сервіс оплат у циклі більше не бере участі.

# Sequence-діаграми сценаріїв SC-01–SC-15

## SC-01: Успішна оплата (`UC-05`, `UC-15`, `REQ-001`, `REQ-003`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant PGW as Платіжний шлюз (Payment Gateway)

    Customer->>Page: clickPayOrder(order_id = 1001)
    activate Page
    Page->>PS: initiatePayment(order_id = 1001)
    activate PS
    PS->>DB: getOrderAndPayments(order_id = 1001)
    activate DB
    DB-->>PS: Orders(status = "new"), Order_Prod(quantity = 2, price_at_purchase = 100), Payment = []
    deactivate DB
    alt Orders.status = "new" і Payment відсутні
        PS->>DB: createPayment(order_id = 1001, amount = 200.00, status = "pending", date = now)
        activate DB
        DB-->>PS: Payment(pay_id = P1, status = "pending", amount = 200.00)
        deactivate DB
        PS->>PGW: createPaymentRequest(pay_id = P1, amount = 200.00, currency = "UAH")
        activate PGW
        PGW-->>PS: checkoutUrl
        deactivate PGW
        PS-->>Page: redirectToGateway(checkoutUrl)
        Page-->>Customer: redirect(checkoutUrl)
    else оплату розпочати не можна
        Note over PS,PGW: відхилення оплати — див. SC-03, SC-04
    end
    deactivate PS
    deactivate Page

    Note over Customer,PGW: Клієнт вводить дані на сторінці шлюзу (поза системою)

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    Note over PS,DB: помилка серіалізації — повтор транзакції до 3 разів (NFR-010)
    PS->>DB: beginTx()
    activate DB
    DB-->>PS: txStarted
    PS->>DB: getPaymentOrderAndStockForUpdate(pay_id = P1)
    DB-->>PS: Payment(status = "pending"), Orders(status = "new"), Order_Prod(quantity = 2), Product(stock = 10)
    alt Product.stock ≥ Order_Prod.quantity для всіх позицій (REQ-003)
        PS->>DB: updatePaymentStatus(pay_id = P1, status = "paid")
        DB-->>PS: ok
        PS->>DB: updateOrderStatus(order_id = 1001, status = "paid")
        DB-->>PS: ok
        PS->>DB: decrementStock(prod_id, quantity = 2)
        DB-->>PS: ok(Product.stock = 8)
    else товару не вистачає хоча б для однієї позиції (REQ-004, див. SC-15)
        PS->>DB: markPaymentPaidAndCancelOrder(pay_id = P1, order_id = 1001)
        DB-->>PS: ok(Orders.status = "cancelled", Product.stock без змін)
    end
    PS->>DB: commitTx()
    DB-->>PS: txCommitted
    deactivate DB
    PS-->>PGW: HTTP 200 OK
    opt Orders.status = "cancelled" (товару не вистачило)
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
    end
    deactivate PS
```

## SC-02: Повторна оплата після невдачі (`UC-05`, `UC-11`, `UC-15`, `REQ-003`, `REQ-008`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant PGW as Платіжний шлюз (Payment Gateway)

    Customer->>Page: clickRetryPayment(order_id = 1001)
    activate Page
    Page->>PS: retryPayment(order_id = 1001)
    activate PS
    PS->>DB: getOrderAndPayments(order_id = 1001)
    activate DB
    DB-->>PS: Orders(status = "new"), Payment(pay_id = P1, status = "failed"), count = 1
    deactivate DB

    alt Orders.status = "new", останній Payment.status = "failed" і count менше 5 (REQ-008)
        PS->>DB: createPayment(order_id = 1001, amount = 200.00, status = "pending", date = now)
        activate DB
        DB-->>PS: Payment(pay_id = P2, status = "pending"), Payment P1 без змін
        deactivate DB
        PS->>PGW: createPaymentRequest(pay_id = P2, amount = 200.00, currency = "UAH")
        activate PGW
        PGW-->>PS: checkoutUrl
        deactivate PGW
        PS-->>Page: redirectToGateway(checkoutUrl)
        Page-->>Customer: redirect(checkoutUrl)
    else count = 5 (REQ-010)
        PS-->>Page: rejectLimitReached("Ліміт спроб оплати вичерпано")
        Page-->>Customer: showErrorMessage("Ліміт спроб оплати вичерпано")
    else замовлення скасоване, оплачене або має pending-платіж (REQ-009)
        PS-->>Page: rejectPayment(message) — див. SC-03
        Page-->>Customer: showErrorMessage(message)
    end
    deactivate PS
    deactivate Page

    Note over Customer,PGW: Клієнт вводить дані на сторінці шлюзу (поза системою)

    PGW->>PS: paymentCallback(pay_id = P2, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: beginTx()
    activate DB
    DB-->>PS: txStarted
    PS->>DB: getPaymentOrderAndStockForUpdate(pay_id = P2)
    DB-->>PS: Payment(status = "pending"), Orders(status = "new"), Order_Prod(quantity = 2), Product(stock = 10)
    alt Product.stock ≥ Order_Prod.quantity для всіх позицій (REQ-003)
        PS->>DB: updatePaymentStatus(pay_id = P2, status = "paid")
        DB-->>PS: ok
        PS->>DB: updateOrderStatus(order_id = 1001, status = "paid")
        DB-->>PS: ok
        PS->>DB: decrementStock(prod_id, quantity = 2)
        DB-->>PS: ok(Product.stock = 8)
    else товару не вистачає хоча б для однієї позиції (REQ-004, див. SC-15)
        PS->>DB: markPaymentPaidAndCancelOrder(pay_id = P2, order_id = 1001)
        DB-->>PS: ok(Orders.status = "cancelled", Product.stock без змін)
    end
    PS->>DB: commitTx()
    DB-->>PS: txCommitted
    deactivate DB
    PS-->>PGW: HTTP 200 OK
    deactivate PS
```

## SC-03: Оплату не можна розпочати (`UC-05`, `REQ-009`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)

    Customer->>Page: clickPayOrder(order_id = 1001)
    activate Page
    Page->>PS: initiatePayment(order_id = 1001)
    activate PS
    PS->>DB: getOrderAndPayments(order_id = 1001)
    activate DB
    DB-->>PS: Orders.status, Payment.status
    deactivate DB

    alt Orders.status == "cancelled"
        PS-->>Page: rejectPayment("Замовлення скасовано")
    else Orders.status == "paid"
        PS-->>Page: rejectPayment("Замовлення вже оплачено")
    else Payment.status == "pending"
        PS-->>Page: rejectPayment("Оплата вже виконується")
    end
    Note over PS: Payment не створюється, звернення до шлюзу немає
    deactivate PS
    Page-->>Customer: showErrorMessage(message)
    deactivate Page
```

## SC-04: Ліміт спроб оплати вичерпано (`UC-05`, `UC-11`, `REQ-010`, `REQ-015`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant PGW as Платіжний шлюз (Payment Gateway)

    Customer->>Page: openOrderPage(order_id = 1001)
    activate Page
    Page->>PS: getPaymentAvailability(order_id = 1001)
    activate PS
    PS->>DB: countPayments(order_id = 1001)
    activate DB
    DB-->>PS: Orders(status = "new"), count = 5, Payment(status = "failed")
    deactivate DB
    alt count менше 5
        PS-->>Page: retryEnabled = true
        Page-->>Customer: renderRetryButton()
    else count = 5
        PS-->>Page: retryEnabled = false
        Page-->>Customer: renderDisabledRetryButton()
    end
    deactivate PS
    deactivate Page

    Note over Customer,Page: Кнопка неактивна, тож спроба оплати надходить прямим запитом
    Customer->>Page: startPayment(order_id = 1001)
    activate Page
    Page->>PS: retryPayment(order_id = 1001)
    activate PS
    PS->>DB: getOrderAndPayments(order_id = 1001)
    activate DB
    DB-->>PS: Orders(status = "new"), count = 5, Payment(status = "failed")
    deactivate DB
    alt Orders.status = "new", останній Payment.status = "failed" і count менше 5 (REQ-008)
        PS->>DB: createPayment(order_id = 1001, amount = 200.00, status = "pending", date = now)
        activate DB
        DB-->>PS: Payment(status = "pending")
        deactivate DB
        PS->>PGW: createPaymentRequest(amount = 200.00, currency = "UAH")
        activate PGW
        PGW-->>PS: checkoutUrl
        deactivate PGW
        PS-->>Page: redirectToGateway(checkoutUrl)
        Page-->>Customer: redirect(checkoutUrl)
    else count = 5 (REQ-010)
        Note over PS,PGW: Payment не створюється, звернення до шлюзу немає
        PS-->>Page: rejectLimitReached("Ліміт спроб оплати вичерпано")
        Page-->>Customer: showErrorMessage("Ліміт спроб оплати вичерпано")
        Page-->>Customer: renderDisabledRetryButton()
    end
    deactivate PS
    deactivate Page
```

## SC-05: Шлюз відхилив платіж (`UC-15`, `REQ-006`, `REQ-015`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant PGW as Платіжний шлюз (Payment Gateway)

    PGW->>PS: paymentCallback(pay_id = P1, status = "declined", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: getPaymentById(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status = "pending")
    deactivate DB
    PS->>DB: markPaymentFailed(pay_id = P1, status = "failed", failure_reason = "declined")
    activate DB
    DB-->>PS: ok(Orders.status = "new")
    deactivate DB
    PS-->>PGW: HTTP 200 OK
    deactivate PS

    Customer->>Page: refreshOrderPage(order_id = 1001)
    activate Page
    Page->>PS: getOrderPaymentState(order_id = 1001)
    activate PS
    PS->>DB: getLastPayment(order_id = 1001)
    activate DB
    DB-->>PS: Payment(status = "failed", failure_reason = "declined"), attempts = 1
    deactivate DB
    alt ліміт спроб не вичерпано (attempts менше 5)
        PS-->>Page: showFailure("Оплату відхилено", retryEnabled = true)
        Page-->>Customer: renderFailureAndRetryButton()
    else ліміт спроб вичерпано (attempts = 5)
        PS-->>Page: showFailure("Оплату відхилено", retryEnabled = false)
        Page-->>Customer: renderFailureWithoutRetryButton()
    end
    deactivate PS
    deactivate Page
```

## SC-06: Шлюз не відповів за 15 хвилин (`UC-15`, `REQ-007`, `REQ-015`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant Sched as Планувальник (Scheduler)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)

    loop кожні 30 секунд (NFR-011)
        activate Sched
        Sched->>DB: findExpiredPendingPayments(Payment.status = "pending", Payment.date старший за 15 хв)
        activate DB
        DB-->>Sched: expiredPayments = [P1]
        deactivate DB
        opt є прострочені платежі (REQ-007)
            Sched->>DB: markPaymentTimeout(pay_id = P1, status = "failed", failure_reason = "timeout", лише якщо Payment.status все ще "pending")
            activate DB
            DB-->>Sched: ok(Orders.status = "new", Product.stock не змінено)
            deactivate DB
        end
        deactivate Sched
    end

    Customer->>Page: viewOrderPage(order_id = 1001)
    activate Page
    Page->>PS: getOrderPaymentState(order_id = 1001)
    activate PS
    PS->>DB: getLastPaymentAndCount(order_id = 1001)
    activate DB
    DB-->>PS: Payment(status = "failed", failure_reason = "timeout"), attempts = 1
    deactivate DB
    alt ліміт спроб не вичерпано (attempts менше 5)
        PS-->>Page: showFailure("Шлюз не відповів вчасно", retryEnabled = true)
        Page-->>Customer: renderFailureAndRetryButton("Шлюз не відповів вчасно")
    else ліміт спроб вичерпано (attempts = 5)
        PS-->>Page: showFailure("Шлюз не відповів вчасно", retryEnabled = false)
        Page-->>Customer: renderFailureWithoutRetryButton("Шлюз не відповів вчасно")
    end
    deactivate PS
    deactivate Page
```

## SC-07: Дубльоване повідомлення шлюзу (`UC-15`, `REQ-011`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant SecLog as Журнал безпеки (Security Log)

    PGW->>PS: paymentCallback(pay_id = P1, status = callbackStatus, signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: getPaymentById(pay_id = P1)
    activate DB
    DB-->>PS: Payment(pay_id = P1, status = currentStatus)
    deactivate DB

    alt дубльована подія (paid/success, failed/declined, refunded/refunded) (REQ-011)
        Note over PS,DB: Payment.status, Orders.status та Product.stock не змінюються, повернення не надсилається
        PS-->>PGW: HTTP 200 OK
    else повідомлення суперечить статусу і не є випадком REQ-002…006, REQ-011, REQ-012 (REQ-016)
        PS->>SecLog: logSecurityEvent(utc_timestamp, pay_id = P1, http_status = 409)
        activate SecLog
        SecLog-->>PS: logged
        deactivate SecLog
        PS-->>PGW: HTTP 409 Conflict
    else очікуваний перехід статусу
        Note over PS,DB: обробка за SC-01, SC-05, SC-09, SC-12, SC-13, SC-14, SC-15
    end
    deactivate PS
```

## SC-08: Суперечливе повідомлення шлюзу (`UC-15`, `REQ-016`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant SecLog as Журнал безпеки (Security Log)

    PGW->>PS: paymentCallback(pay_id = P1, status = "declined", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: getPaymentById(pay_id = P1)
    activate DB
    DB-->>PS: Payment(pay_id = P1, status = "paid")
    deactivate DB

    alt повідомлення суперечить поточному статусу платежу
        Note over PS,DB: Payment.status = "paid", Orders.status і Product.stock без змін
        PS->>SecLog: logSecurityEvent(utc_timestamp, pay_id = P1, http_status = 409)
        activate SecLog
        SecLog-->>PS: logged
        deactivate SecLog
        PS-->>PGW: HTTP 409 Conflict
    end
    deactivate PS
```

## SC-09: Запізніле success після таймауту, замовлення ще new (`UC-15`, `REQ-003`, `REQ-012`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: beginTx()
    activate DB
    DB-->>PS: txStarted
    PS->>DB: getPaymentOrderAndStockForUpdate(pay_id = P1)
    DB-->>PS: Payment(status = "failed", failure_reason = "timeout"), Orders(order_id = 1001, status), Order_Prod(quantity = 2), Product(stock = 10)

    alt Orders.status == "new" і Product.stock ≥ Order_Prod.quantity для всіх позицій (REQ-003)
        PS->>DB: updatePaymentStatus(pay_id = P1, status = "paid")
        DB-->>PS: ok
        PS->>DB: updateOrderStatus(order_id = 1001, status = "paid")
        DB-->>PS: ok
        PS->>DB: decrementStock(prod_id, quantity = 2)
        DB-->>PS: ok(Product.stock = 8)
    else Orders.status == "new", але товару не вистачає хоча б для однієї позиції (REQ-004)
        PS->>DB: markPaymentPaidAndCancelOrder(pay_id = P1, order_id = 1001)
        DB-->>PS: ok(Orders.status = "cancelled", Product.stock без змін)
    else Orders.status != "new"
        Note over PS,DB: зміни не потрібні, далі за SC-12 (paid) або SC-13 (cancelled)
    end
    PS->>DB: commitTx()
    DB-->>PS: txCommitted
    deactivate DB
    PS-->>PGW: HTTP 200 OK

    opt Orders.status = "cancelled" (товару не вистачило)
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
    end
    deactivate PS
```

## SC-10: Повідомлення з недійсним підписом (`UC-15`, `REQ-013`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant SecLog as Журнал безпеки (Security Log)

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    alt підпис недійсний
        PS->>SecLog: logSecurityEvent(utc_timestamp, pay_id = P1, http_status = 401)
        activate SecLog
        SecLog-->>PS: logged
        deactivate SecLog
        Note over PS: дані платежу не читались і не змінювались
        PS-->>PGW: HTTP 401 Unauthorized
    else підпис дійсний
        PS->>PS: processCallback(pay_id = P1) — див. SC-01
    end
    deactivate PS
```

## SC-11: Повідомлення про невідомий платіж (`UC-15`, `REQ-014`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant SecLog as Журнал безпеки (Security Log)

    PGW->>PS: paymentCallback(pay_id = P9999, status = "success", validSignature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, validSignature)
    PS->>DB: getPaymentById(pay_id = P9999)
    activate DB
    DB-->>PS: notFound
    deactivate DB

    alt платіж не знайдено
        PS->>SecLog: logSecurityEvent(utc_timestamp, pay_id = P9999, http_status = 404)
        activate SecLog
        SecLog-->>PS: logged
        deactivate SecLog
        Note over PS,DB: дані замовлень, платежів і залишків не змінено
        PS-->>PGW: HTTP 404 Not Found
    end
    deactivate PS
```

## SC-12: Запізніле success після таймауту, замовлення вже оплачене (`UC-14`, `UC-15`, `REQ-002`, `REQ-005`, `REQ-012`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: getPaymentAndOrder(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status = "failed", failure_reason = "timeout"), Orders(order_id = 1001, status)
    deactivate DB

    alt Orders.status == "paid"
        PS->>DB: markPaymentPaidKeepOrder(pay_id = P1, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment.status = "paid", Orders.status = "paid", Product.stock без змін)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
        deactivate PS

        PGW->>PS: refundCallback(pay_id = P1, status = "refunded", signature)
        activate PS
        PS->>PS: verifyHmacSha256(payload, signature)
        PS->>DB: markPaymentRefunded(pay_id = P1, status = "refunded")
        activate DB
        DB-->>PS: committed(Payment.status = "refunded", Orders.status = "paid", Product.stock без змін)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "paid"
        Note over PS,DB: new — див. SC-09, cancelled — див. SC-13
        PS-->>PGW: HTTP 200 OK
    end
    deactivate PS
```

## SC-13: Запізніле success після таймауту, замовлення скасоване (`UC-14`, `UC-15`, `REQ-002`, `REQ-005`, `REQ-012`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: getPaymentAndOrder(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status = "failed", failure_reason = "timeout"), Orders(order_id = 1001, status)
    deactivate DB

    alt Orders.status == "cancelled"
        PS->>DB: markPaymentPaidKeepCancelledOrder(pay_id = P1, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment.status = "paid", Orders.status = "cancelled", Product.stock без змін)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
        deactivate PS

        PGW->>PS: refundCallback(pay_id = P1, status = "refunded", signature)
        activate PS
        PS->>PS: verifyHmacSha256(payload, signature)
        PS->>DB: markPaymentRefunded(pay_id = P1, status = "refunded")
        activate DB
        DB-->>PS: committed(Payment.status = "refunded", Orders.status = "cancelled")
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "cancelled"
        Note over PS,DB: new — див. SC-09, paid — див. SC-12
        PS-->>PGW: HTTP 200 OK
    end
    deactivate PS
```

## SC-14: Другий платіж успішний, а замовлення вже оплачене (`UC-14`, `UC-15`, `REQ-002`, `REQ-005`)

```mermaid
sequenceDiagram
    autonumber
    participant PGW as Платіжний шлюз (Payment Gateway)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)

    PGW->>PS: paymentCallback(pay_id = P2, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: getPaymentAndOrder(pay_id = P2)
    activate DB
    DB-->>PS: Payment(pay_id = P2, status = "pending"), Orders(order_id = 1001, status), Payment(pay_id = P1, status)
    deactivate DB

    alt Orders.status == "paid"
        PS->>DB: markPaymentPaidKeepOrder(pay_id = P2, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment P2 status = "paid", Orders.status = "paid", Product.stock без змін)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
        PS->>PGW: refundPayment(pay_id = P2, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
        deactivate PS

        PGW->>PS: refundCallback(pay_id = P2, status = "refunded", signature)
        activate PS
        PS->>PS: verifyHmacSha256(payload, signature)
        PS->>DB: markPaymentRefunded(pay_id = P2, status = "refunded")
        activate DB
        DB-->>PS: committed(Payment P2 status = "refunded", Payment P1 status = "paid")
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "paid"
        Note over PS,DB: обробка за SC-01, SC-02 (замовлення new) або SC-13 (cancelled)
        PS-->>PGW: HTTP 200 OK
    end
    deactivate PS
```

## SC-15: Гроші отримано, але товару вже немає (`UC-14`, `UC-15`, `REQ-004`, `REQ-005`)

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Клієнт (Customer)
    participant Page as Сторінка замовлення (Order Page)
    participant PS as Сервіс оплат (Payment Service)
    participant DB as База даних (Database)
    participant PGW as Платіжний шлюз (Payment Gateway)

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: beginTx()
    activate DB
    DB-->>PS: txStarted
    PS->>DB: getPaymentOrderAndStockForUpdate(pay_id = P1)
    DB-->>PS: Payment(status = "pending"), Orders(status = "new"), Product(stock = 1), Order_Prod(quantity = 2)
    alt товару не вистачає хоча б для однієї позиції (Product.stock менше Order_Prod.quantity)
        PS->>DB: markPaymentPaidAndCancelOrder(pay_id = P1, order_id = 1001)
        DB-->>PS: ok(Payment.status = "paid", Orders.status = "cancelled", Product.stock = 1)
    else Product.stock ≥ Order_Prod.quantity для всіх позицій
        Note over PS,DB: успішне зарахування — див. SC-01
    end
    PS->>DB: commitTx()
    DB-->>PS: txCommitted
    deactivate DB
    PS-->>PGW: HTTP 200 OK
    opt Orders.status = "cancelled" (REQ-004)
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
    end
    deactivate PS

    Customer->>Page: viewOrderPage(order_id = 1001)
    activate Page
    Page->>PS: getOrderPaymentState(order_id = 1001)
    activate PS
    PS->>DB: getOrderAndLastPayment(order_id = 1001)
    activate DB
    DB-->>PS: Orders(status = "cancelled"), Payment(status = "paid")
    deactivate DB
    alt Orders.status == "cancelled"
        PS-->>Page: showMessage("Товар закінчився, кошти буде повернено")
        Page-->>Customer: showMessage("Товар закінчився, кошти буде повернено")
    else інший статус замовлення
        PS-->>Page: orderState
        Page-->>Customer: renderOrderState()
    end
    deactivate PS
    deactivate Page

    PGW->>PS: refundCallback(pay_id = P1, status = "refunded", signature)
    activate PS
    PS->>PS: verifyHmacSha256(payload, signature)
    PS->>DB: markPaymentRefunded(pay_id = P1, status = "refunded")
    activate DB
    DB-->>PS: committed(Payment.status = "refunded", Orders.status = "cancelled")
    deactivate DB
    PS-->>PGW: HTTP 200 OK
    deactivate PS
```