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
    DB-->>PS: Orders(status="new"), Payment=[]
    deactivate DB
    PS->>DB: createPayment(order_id = 1001, amount = 200.00, status = "pending", date = now)
    activate DB
    DB-->>PS: Payment(pay_id = P1, status = "pending")
    deactivate DB
    PS->>PGW: createPaymentRequest(pay_id = P1, amount = 200.00)
    activate PGW
    PGW-->>PS: checkoutUrl
    deactivate PGW
    PS-->>Page: redirectToGateway(checkoutUrl)
    deactivate PS
    Page-->>Customer: redirect(checkoutUrl)
    deactivate Page

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>DB: beginTx()
    activate DB
    alt товару вистачає (Product.stock >= Order_Prod.quantity)
        PS->>DB: updatePaymentStatus(pay_id = P1, status = "paid")
        PS->>DB: updateOrderStatus(order_id = 1001, status = "paid")
        PS->>DB: decrementStock(prod_id, quantity = 2)
        DB-->>PS: txCommitted
        deactivate DB
        PS-->>PGW: HTTP 200 OK
        PS->>Page: notifyOrderPaid(order_id = 1001)
        activate Page
        Page-->>Customer: showOrderPaidStatus()
        deactivate Page
    else товару не вистачає
        PS->>DB: rollbackTx()
        PS-->>PGW: HTTP 409 Conflict
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
    DB-->>PS: Orders(status="new"), Payment(pay_id=P1, status="failed"), count=1
    deactivate DB

    alt ліміт спроб не вичерпано (count менше 5)
        PS->>DB: createPayment(order_id = 1001, amount = 200.00, status = "pending", date = now)
        activate DB
        DB-->>PS: Payment(pay_id = P2, status = "pending")
        deactivate DB
        PS->>PGW: createPaymentRequest(pay_id = P2, amount = 200.00)
        activate PGW
        PGW-->>PS: checkoutUrl
        deactivate PGW
        PS-->>Page: redirectToGateway(checkoutUrl)
        Page-->>Customer: redirect(checkoutUrl)
    else ліміт спроб вичерпано
        PS-->>Page: rejectLimitReached("Ліміт спроб оплати вичерпано")
        Page-->>Customer: showErrorMessage("Ліміт спроб оплати вичерпано")
    end
    deactivate PS
    deactivate Page

    opt платіж створено, шлюз надсилає результат
        PGW->>PS: paymentCallback(pay_id = P2, status = "success", signature)
        activate PS
        PS->>DB: updatePaymentAndOrderPaid(pay_id = P2, order_id = 1001, prod_id, quantity = 2)
        activate DB
        DB-->>PS: updated(Product.stock = 8)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
        deactivate PS
    end
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
        deactivate PS
    else Orders.status == "paid"
        PS-->>Page: rejectPayment("Замовлення вже оплачено")
    else Payment.status == "pending"
        PS-->>Page: rejectPayment("Оплата вже виконується")
    end
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

    Customer->>Page: openOrderPage(order_id = 1001)
    activate Page
    Page->>PS: getPaymentAvailability(order_id = 1001)
    activate PS
    PS->>DB: countPayments(order_id = 1001)
    activate DB
    DB-->>PS: count = 5, Payment(status = "failed")
    deactivate DB
    alt ліміт спроб не вичерпано (count менше 5)
        PS-->>Page: retryEnabled = true
        Page-->>Customer: renderRetryButton()
    else ліміт спроб вичерпано (count = 5)
        PS-->>Page: retryEnabled = false
        Page-->>Customer: renderDisabledRetryButton()
    end
    deactivate PS
    deactivate Page

    Customer->>Page: clickRetryPayment(order_id = 1001)
    activate Page
    Page->>PS: retryPayment(order_id = 1001)
    activate PS
    PS->>DB: countPayments(order_id = 1001)
    activate DB
    DB-->>PS: count = 5
    deactivate DB
    alt ліміт спроб не вичерпано (count менше 5)
        PS-->>Page: paymentAllowed
        Page-->>Customer: redirectToPayment()
    else ліміт спроб вичерпано (count = 5)
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
        Sched->>PS: scanExpiredPendingPayments(thresholdMinutes = 15)
        activate PS
        PS->>DB: findExpiredPendingPayments(status = "pending", olderThan = 15m)
        activate DB
        DB-->>PS: expiredPayments=[P1]
        deactivate DB
        opt є прострочені платежі
            PS->>DB: markPaymentTimeout(pay_id = P1, status = "failed", failure_reason = "timeout")
            activate DB
            DB-->>PS: ok(Orders.status = "new", Product.stock не змінено)
            deactivate DB
        end
        deactivate PS
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

    PGW->>PS: paymentCallback(pay_id = P1, status = "success", signature)
    activate PS
    PS->>DB: getPaymentById(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status = "paid")
    deactivate DB

    alt статус вже відповідає події (paid/success, failed/declined, refunded/refunded)
        PS-->>PGW: HTTP 200 OK
    else інший випадок
        PS-->>PGW: HTTP 409 Conflict
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
    PS->>DB: getPaymentById(pay_id = P1)
    activate DB
    DB-->>PS: Payment(pay_id = P1, status)
    deactivate DB
    alt Payment.status == "paid" (суперечить status = "declined")
        PS->>SecLog: logConflictEvent(utc_timestamp, pay_id = P1, http_status = 409)
        activate SecLog
        SecLog-->>PS: logged(Payment.status = "paid", Orders.status і Product.stock без змін)
        deactivate SecLog
        PS-->>PGW: HTTP 409 Conflict
    else Payment.status == "pending"
        PS->>DB: markPaymentFailed(pay_id = P1, status = "failed", failure_reason = "declined")
        activate DB
        DB-->>PS: ok(Orders.status = "new", Product.stock без змін)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
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
    PS->>DB: getPaymentAndOrder(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status="failed", failure_reason="timeout"), Orders(order_id=1001, status)
    deactivate DB
    alt Orders.status == "new"
        PS->>DB: settlePaymentAndOrderPaid(pay_id = P1, order_id = 1001, prod_id, quantity = 2)
        activate DB
        DB-->>PS: committed(Payment.status="paid", Orders.status="paid", Product.stock=8)
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "new"
        PS->>PS: handleLateSuccess(pay_id = P1) — див. SC-12, SC-13
        PS-->>PGW: HTTP 200 OK
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
        SecLog-->>PS: logged(дані не змінено)
        deactivate SecLog
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
    PS->>DB: getPaymentById(pay_id = P9999)
    activate DB
    DB-->>PS: notFound або Payment(pay_id = P9999)
    deactivate DB
    alt платіж не знайдено
        PS->>SecLog: logSecurityEvent(utc_timestamp, pay_id = P9999, http_status = 404)
        activate SecLog
        SecLog-->>PS: logged(дані не змінено)
        deactivate SecLog
        PS-->>PGW: HTTP 404 Not Found
    else платіж знайдено
        PS->>PS: processCallback(pay_id = P9999) — див. SC-01
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
    PS->>DB: getPaymentAndOrder(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status="failed", failure_reason="timeout"), Orders(order_id=1001, status)
    deactivate DB

    alt Orders.status == "paid"
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW

        PS->>DB: markPaymentPaidKeepOrder(pay_id = P1, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment.status="paid", Orders.status="paid")
        deactivate DB
        PS-->>PGW: HTTP 200 OK

        PGW->>PS: refundCallback(pay_id = P1, status = "refunded", signature)
        PS->>DB: markPaymentRefunded(pay_id = P1, status = "refunded")
        activate DB
        DB-->>PS: committed
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "paid"
        PS->>PS: handleLateSuccess(pay_id = P1) — див. SC-09, SC-13
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
    PS->>DB: getPaymentAndOrder(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status="failed", failure_reason="timeout"), Orders(order_id=1001, status)
    deactivate DB
    alt Orders.status == "cancelled"
        PS->>DB: markPaymentPaidKeepCancelledOrder(pay_id = P1, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment.status="paid", Orders.status="cancelled")
        deactivate DB
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
        PS-->>PGW: HTTP 200 OK

        PGW->>PS: refundCallback(pay_id = P1, status = "refunded", signature)
        activate PS
        PS->>DB: markPaymentRefunded(pay_id = P1, status = "refunded")
        activate DB
        DB-->>PS: committed
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "cancelled"
        PS->>PS: handleLateSuccess(pay_id = P1) — див. SC-09, SC-12
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
    PS->>DB: getPaymentAndOrder(pay_id = P2)
    activate DB
    DB-->>PS: Payment(pay_id=P2, status="pending"), Orders(order_id=1001, status), Payment(pay_id=P1, status)
    deactivate DB
    alt Orders.status == "paid"
        PS->>DB: markPaymentPaidKeepOrder(pay_id = P2, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment.status="paid", Orders.status="paid")
        deactivate DB
        PS->>PGW: refundPayment(pay_id = P2, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
        PS-->>PGW: HTTP 200 OK

        PGW->>PS: refundCallback(pay_id = P2, status = "refunded", signature)
        activate PS
        PS->>DB: markPaymentRefunded(pay_id = P2, status = "refunded")
        activate DB
        DB-->>PS: committed(Payment(pay_id=P2, status="refunded"), Payment(pay_id=P1, status="paid"))
        deactivate DB
        PS-->>PGW: HTTP 200 OK
    else Orders.status != "paid"
        PS->>PS: processCallback(pay_id = P2) — див. SC-01, SC-02
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
    PS->>DB: getPaymentOrderAndStock(pay_id = P1)
    activate DB
    DB-->>PS: Payment(status="pending"), Orders(status="new"), Product.stock=1, Order_Prod.quantity=2
    deactivate DB
    alt Product.stock менше Order_Prod.quantity
        PS->>DB: markPaymentPaidAndCancelOrder(pay_id = P1, order_id = 1001)
        activate DB
        DB-->>PS: committed(Payment.status="paid", Orders.status="cancelled", Product.stock=1)
        deactivate DB
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
        PS-->>PGW: HTTP 200 OK
    else Product.stock >= Order_Prod.quantity
        PS->>PS: completeOrder(pay_id = P1) — див. SC-01
        PS-->>PGW: HTTP 200 OK
    end
    deactivate PS

    Customer->>Page: viewOrderPage(order_id = 1001)
    activate Page
    Page-->>Customer: showMessage("Товар закінчився, кошти буде повернено")
    deactivate Page

    PGW->>PS: refundCallback(pay_id = P1, status = "refunded", signature)
    activate PS
    PS->>DB: markPaymentRefunded(pay_id = P1, status = "refunded")
    activate DB
    DB-->>PS: committed
    deactivate DB
    PS-->>PGW: HTTP 200 OK
    deactivate PS
```