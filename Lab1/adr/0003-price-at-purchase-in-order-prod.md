Зберігати ціну на момент покупки в Order_Prod.price_at_purchase
Context and Problem Statement

Ціна товару (Product.price) змінюється з часом, а сума вже оформленого замовлення змінюватися не повинна. Де зберігати ціну, за якою товар купили?

Decision Drivers
незмінність минулих замовлень
відповідність 3НФ, якщо дублювання не виправдане
Considered Options
брати ціну з Product.price під час читання замовлення
зберігати ціну в позиції замовлення (Order_Prod.price_at_purchase)
Decision Outcome

Chosen option: "зберігати price_at_purchase в Order_Prod", because ціна на момент покупки є атрибутом зв'язку замовлення з товаром, а не товару.

Consequences
Good, because сума минулих замовлень не залежить від зміни ціни.
Bad, because дублювання Product.price. Це свідомий виняток з 3НФ (spec.md, розділ 5, п. 2).
Confirmation

У model.mmd сутність Order_Prod має поля quantity і price_at_purchase.

Pros and Cons of the Options
Ціна з Product.price
Good, because немає дублювання.
Bad, because історичні замовлення змінюються разом із ціною.
price_at_purchase
Good, because історія стабільна.
Bad, because навмисне дублювання.