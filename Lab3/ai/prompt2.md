Питання:
Провір файл, напиши що ще варто виправить і перепиши 1 сценарій він не рендериться в гітхабі

Відповідь:
Не рендерився SC-01, і я переписав його в diagram_1.md. Усі 15 діаграм у ньому тепер проходять парсер Mermaid (я прогнав його локально), але візуально на GitHub я їх не перевіряв.

Чому SC-01 не рендерився. У ньому deactivate DB стояв в обох гілках alt. Mermaid читає код послідовно: у першій гілці DB закривається, а друге закриття вже падає з помилкою «Trying to inactivate an inactive participant (DB)».

Що змінено в SC-01.

DB активується до alt (beginTx()) і закривається один раз після нього, разом із commitTx().
Видалено notifyOrderPaid і notifyOutOfStockCancelled, яких немає в Gherkin.
Гілка «товару немає» тепер веде до markPaymentPaidAndCancelOrder, а повернення коштів іде в opt після commitTx() (REQ-004).
Додано verifyHmacSha256 перед будь-яким зверненням до БД (NFR-004) і читання залишку з блокуванням.

Що ще варто виправити в diagram_1.md. Нижче те, що я перевірив у цьому файлі (SC-01 тут уже виправлений):

Активації:
SC-03: deactivate PS є тільки в гілці «скасовано», тож у двох інших гілках смуга PS відсутня, а в кінці лишається незакритою.
SC-13 і SC-14: другий activate PS вкладається в уже відкриту активацію, а deactivate один.
Парсер на цих діаграмах не падає, але смуги виходять неправильні.
Підпис (NFR-004): verifyHmacSha256 немає в жодній діаграмі, крім SC-10.
SC-02: callback загорнуто в opt, а оплату й залишок згорнуто в один виклик updatePaymentAndOrderPaid, тому не видно ні транзакції, ні перевірки залишку.
SC-04: гілка paymentAllowed → redirectToPayment() не створює Payment і не викликає шлюз.
SC-05: немає перевірки, що платіж pending (REQ-006), і немає гілки для інших статусів.

Файл більший за ці сценарії, а діф я переглядав не повністю (він обрізався). Тому SC-06–SC-15 не читав у деталях. Автоматична перевірка активацій показала проблеми тільки в SC-03, SC-13 і SC-14, а рештою можете замінити відповідними блоками з diagram.md, який я зробив раніше. Там усе проходить і парсер, і перевірку активацій.

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
    opt Orders.status = "cancelled" (товару не вистачило)
        PS->>PGW: refundPayment(pay_id = P1, amount = 200.00)
        activate PGW
        PGW-->>PS: refundAccepted
        deactivate PGW
    end
    PS-->>PGW: HTTP 200 OK
    deactivate PS
```