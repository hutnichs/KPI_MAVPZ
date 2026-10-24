Feature: Оплата замовлення
  UC-05 Оплатити замовлення разом з UC-11, UC-14 і UC-15.
  Усі сценарії однієї потреби: гроші за замовлення мають надійти, а стан замовлення і залишків має відповідати фактичним платежам.

  Background:
    Given Клієнт "Анна" авторизований
    And існує Product "Корм А" з price = 100
    And існує Orders №1001 клієнта "Анна" з однією позицією Order_Prod: "Корм А", quantity = 2, price_at_purchase = 100

  Rule: Клієнт оплачує замовлення (UC-05, UC-11)
    Як Клієнт,
    я хочу оплатити створене замовлення онлайн і повторити оплату після невдачі,
    щоб магазин узяв замовлення у виконання, а я не втратив гроші в разі збою.

    @SC-01 @UC-05 @UC-15 @REQ-001 @REQ-003
    Scenario: Успішна оплата
      Given Orders №1001 має status "new" і не має жодного Payment
      And Product "Корм А" має stock = 10
      When Клієнт починає оплату Orders №1001
      Then створено Payment зі status "pending" і amount = 200.00
      And Платіжний шлюз отримав запит на оплату на суму 200.00 UAH з номером цього Payment
      And Клієнта перенаправлено на платіжну сторінку шлюзу
      When Платіжний шлюз надсилає правильне повідомлення "success" для цього Payment
      Then Payment.status = "paid"
      And Orders.status = "paid"
      And Product "Корм А" має stock = 8

    @SC-02 @UC-05 @UC-11 @UC-15 @REQ-003 @REQ-008
    Scenario: Повторна оплата після невдачі
      Given Orders №1001 має status "new" і один Payment №P1 зі status "failed"
      And Product "Корм А" має stock = 10
      When Клієнт починає оплату Orders №1001
      Then створено новий Payment №P2 зі status "pending" і amount = 200.00
      And новий Orders не створювався
      And Платіжний шлюз отримав запит на суму 200.00 UAH з номером Payment №P2
      When Платіжний шлюз надсилає правильне повідомлення "success" для Payment №P2
      Then Payment №P2 має status "paid"
      And Payment №P1 лишається зі status "failed"
      And Orders.status = "paid"
      And Product "Корм А" має stock = 8

    @SC-03 @UC-05 @REQ-009
    Scenario Outline: Оплату не можна розпочати
      Given Orders №1001 має status "<order_status>"
      And Orders №1001 має Payment зі status "<payment_status>"
      When Клієнт починає оплату Orders №1001
      Then нового Payment не створено
      And запит до Платіжного шлюзу не надсилався
      And Клієнт бачить повідомлення "<message>"

      Examples:
        | order_status | payment_status | message                |
        | cancelled    | paid           | Замовлення скасовано   |
        | paid         | paid           | Замовлення вже оплачено |
        | new          | pending        | Оплата вже виконується |

    @SC-04 @UC-05 @UC-11 @REQ-010 @REQ-015
    Scenario: Ліміт спроб оплати вичерпано
      Given Orders №1001 має status "new" і 5 Payment, останній має status "failed"
      When Клієнт починає оплату Orders №1001
      Then нового Payment не створено
      And запит до Платіжного шлюзу не надсилався
      And кнопка "Повторити оплату" неактивна
      And Клієнт бачить повідомлення "Ліміт спроб оплати вичерпано"

  Rule: Платіжний шлюз повідомляє результат платежу (UC-15)
    Як Платіжний шлюз,
    я хочу передати системі результат платежу,
    щоб статуси платежів, замовлень і залишки товарів відповідали фактичним платежам.

    @SC-05 @UC-15 @REQ-006 @REQ-015
    Scenario: Шлюз відхилив платіж
      Given Orders №1001 має status "new"
      And Product "Корм А" має stock = 10
      And існує Payment №P1 для Orders №1001 зі status "pending"
      When Платіжний шлюз надсилає правильне повідомлення "declined" для Payment №P1
      Then Payment №P1 має status "failed" і причину "declined"
      And Orders.status = "new"
      And Product "Корм А" має stock = 10
      And Клієнт бачить на сторінці замовлення повідомлення "Оплату відхилено"
      And кнопка "Повторити оплату" активна

    @SC-06 @UC-15 @REQ-007 @REQ-015
    Scenario: Шлюз не відповів за 15 хвилин
      Given Orders №1001 має status "new"
      And Product "Корм А" має stock = 10
      And існує Payment №P1 для Orders №1001 зі status "pending" і часом створення 12:00:00
      When минуло 15 хвилин від часу створення і відповіді від шлюзу не було
      Then не пізніше 12:16:00 Payment №P1 має status "failed" і причину "timeout"
      And Orders.status = "new"
      And Product "Корм А" має stock = 10
      And Клієнт бачить на сторінці замовлення повідомлення "Шлюз не відповів вчасно"
      And кнопка "Повторити оплату" активна

    @SC-07 @UC-15 @REQ-011
    Scenario Outline: Дубльоване повідомлення шлюзу
      Given Payment №P1 для Orders №1001 має status "<status>"
      And Product "Корм А" має stock = 8
      When Платіжний шлюз надсилає правильне повідомлення "<callback>" для Payment №P1
      Then система відповідає HTTP 200
      And Payment №P1 лишається зі status "<status>"
      And Product "Корм А" має stock = 8
      And запит на повернення коштів не надсилається

      Examples:
        | status   | callback |
        | paid     | success  |
        | failed   | declined |
        | refunded | refunded |

    @SC-08 @UC-15 @REQ-016
    Scenario: Суперечливе повідомлення шлюзу
      Given Payment №P1 має status "paid"
      And Product "Корм А" має stock = 8
      When Платіжний шлюз надсилає правильне повідомлення "declined" для Payment №P1
      Then система відповідає HTTP 409
      And Payment №P1 лишається зі status "paid"
      And Product "Корм А" має stock = 8
      And подію записано в журнал безпеки

    @SC-09 @UC-15 @REQ-003 @REQ-012
    Scenario: Запізніле success після таймауту, замовлення ще new
      Given Payment №P1 має status "failed" і причину "timeout"
      And Orders №1001 має status "new"
      And Product "Корм А" має stock = 10
      When Платіжний шлюз надсилає правильне повідомлення "success" для Payment №P1
      Then Payment №P1 має status "paid"
      And Orders.status = "paid"
      And Product "Корм А" має stock = 8
      And запит на повернення коштів не надсилається

    @SC-10 @UC-15 @REQ-013
    Scenario: Повідомлення з недійсним підписом
      Given Orders №1001 має status "new"
      And Product "Корм А" має stock = 10
      And існує Payment №P1 для Orders №1001 зі status "pending"
      When надходить повідомлення "success" для Payment №P1 з недійсним підписом
      Then система відповідає HTTP 401
      And Payment №P1 лишається зі status "pending"
      And Product "Корм А" має stock = 10
      And у журналі безпеки є запис про подію

    @SC-11 @UC-15 @REQ-014
    Scenario: Повідомлення про невідомий платіж
      Given Payment №P9999 не існує
      And Product "Корм А" має stock = 10
      When надходить повідомлення "success" для Payment №P9999 з дійсним підписом
      Then система відповідає HTTP 404
      And дані замовлень і платежів не змінюються
      And Product "Корм А" має stock = 10
      And у журналі безпеки є запис про подію

  Rule: Клієнт отримує кошти назад (UC-14)
    Як Клієнт,
    я хочу, щоб гроші, які надійшли, але не можуть бути зараховані до замовлення, були мені повернені,
    щоб я не заплатив за товар, якого не отримаю, або двічі за те саме замовлення.

    @SC-12 @UC-14 @UC-15 @REQ-002 @REQ-005 @REQ-012
    Scenario: Запізніле success після таймауту, замовлення вже оплачене
      Given Orders №1001 має status "paid"
      And Payment №P1 має status "failed" і причину "timeout"
      And Product "Корм А" має stock = 8
      When Платіжний шлюз надсилає правильне повідомлення "success" для Payment №P1
      Then Payment №P1 має status "paid"
      And Orders.status лишається "paid"
      And Product "Корм А" має stock = 8
      And Платіжному шлюзу надсилається запит на повернення 200.00 UAH для Payment №P1
      When Платіжний шлюз надсилає правильне повідомлення "refunded" для Payment №P1
      Then Payment №P1 має status "refunded"

    @SC-13 @UC-14 @UC-15 @REQ-002 @REQ-005 @REQ-012
    Scenario: Запізніле success після таймауту, замовлення скасоване
      Given Orders №1001 має status "cancelled"
      And Payment №P1 має status "failed" і причину "timeout"
      And Product "Корм А" має stock = 10
      When Платіжний шлюз надсилає правильне повідомлення "success" для Payment №P1
      Then Payment №P1 має status "paid"
      And Orders.status лишається "cancelled"
      And Product "Корм А" має stock = 10
      And Платіжному шлюзу надсилається запит на повернення 200.00 UAH для Payment №P1
      When Платіжний шлюз надсилає правильне повідомлення "refunded" для Payment №P1
      Then Payment №P1 має status "refunded"

    @SC-14 @UC-14 @UC-15 @REQ-002 @REQ-005
    Scenario: Другий платіж успішний, а замовлення вже оплачене
      Given Orders №1001 має status "paid"
      And Payment №P1 має status "paid"
      And Payment №P2 має status "pending"
      And Product "Корм А" має stock = 8
      When Платіжний шлюз надсилає правильне повідомлення "success" для Payment №P2
      Then Payment №P2 має status "paid"
      And Orders.status лишається "paid"
      And Product "Корм А" має stock = 8
      And Платіжному шлюзу надсилається запит на повернення 200.00 UAH для Payment №P2
      When Платіжний шлюз надсилає правильне повідомлення "refunded" для Payment №P2
      Then Payment №P2 має status "refunded"
      And Payment №P1 лишається зі status "paid"

    @SC-15 @UC-14 @UC-15 @REQ-004 @REQ-005
    Scenario: Гроші отримано, але товару вже немає
      Given Orders №1001 має status "new"
      And Payment №P1 має status "pending"
      And Product "Корм А" має stock = 1
      When Платіжний шлюз надсилає правильне повідомлення "success" для Payment №P1
      Then Payment №P1 має status "paid"
      And Orders.status = "cancelled"
      And Product "Корм А" має stock = 1
      And запит на повернення 200.00 UAH для Payment №P1 надіслано після збереження цих змін у базі
      And Клієнт бачить на сторінці замовлення повідомлення "Товар закінчився, кошти буде повернено"
      When Платіжний шлюз надсилає правильне повідомлення "refunded" для Payment №P1
      Then Payment №P1 має status "refunded"
