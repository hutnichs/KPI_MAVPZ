Питання: Напиши 3 файла ADR на основі того що було в spec.md
Відповідь:
Зберігати стан тварини у відгуку через асоціативну сутність Review_Pet_Snapshot
Context and Problem Statement

Відгук має зберігати стан тварини на момент написання, а один відгук може стосуватися кількох тварин. Тварина з часом змінюється (вік, special_needs) або може бути позначена видаленою. Як змоделювати зв'язок між Review і Pet?

Decision Drivers
один відгук може стосуватися 0..N тварин
стан тварини на момент відгуку не має змінюватися разом із Pet
асоціативна сутність допустима лише тоді, коли зв'язок має власні атрибути (AC-4)
дані мають бути структурованими, а не вільним текстом
Considered Options
Review.pet_id (прямий FK)
чисте M:N між Review і Pet (прямий зв'язок)
Review_Pet + текстове поле Review.pet_info
Review_Pet_Snapshot (асоціативна сутність з атрибутами тварини)
Decision Outcome

Chosen option: "Review_Pet_Snapshot", because зв'язок має власні атрибути (стан тварини на момент відгуку), тож асоціативна сутність виправдана, а історія не залежить від змін у Pet.

Consequences
Good, because у відгуку може бути кілька тварин, кожна зі своїм станом.
Good, because стан структурований: кожен атрибут окремо.
Bad, because атрибути Pet дублюються. Це свідомий виняток з 3НФ (spec.md, розділ 5, п. 1).
Confirmation

У model.mmd є сутність Review_Pet_Snapshot зі складеним PK (pet_id, review_id) і зв'язками 1 : N до Pet та Review; поля Review.pet_id і Review.pet_info відсутні.

Pros and Cons of the Options
Review.pet_id
Good, because найпростіша модель.
Bad, because одна тварина на відгук.
Bad, because історичний стан не зберігається.
Чисте M:N між Review і Pet
Good, because кілька тварин у відгуку.
Bad, because стан на момент відгуку немає де зберегти.
Review_Pet + Review.pet_info
Good, because стан тварини якось зберігається.
Bad, because одне текстове поле на кілька тварин, незрозуміло, що до якої належить.
Bad, because вільний текст не можна структуровано перевірити.
Bad, because сполучна таблиця без атрибутів суперечить AC-4.
Review_Pet_Snapshot
Good, because кілька тварин, структурований стан, історія захищена.
Bad, because дублювання даних (навмисне).

Моделювати чисті M:N (вішліст, теги) прямим зв'язком без сполучної сутності
Context and Problem Statement

Клієнт може додати у вішліст багато товарів, а товар бути у вішлістах багатьох клієнтів. Товар має багато тегів, тег стосується багатьох товарів. Жоден із цих зв'язків не несе власних атрибутів. Як їх зобразити в ER-моделі?

Decision Drivers
завдання вимагає, щоб чистий M:N був зв'язком між сутностями, а не сполучною таблицею (на кшталт user_roles)
ER-модель не є фізичною схемою БД
менше сутностей і менше шуму в діаграмі
Considered Options
окремі сутності Wishlist та Prod_Tag
прямий зв'язок }o--o{
Decision Outcome

Chosen option: "прямий зв'язок }o--o{", because зв'язки не мають власних атрибутів, а сполучні таблиці належать до фізичної схеми, яка поза межами роботи.

Consequences
Good, because модель відповідає вимозі завдання й критерію AC-4.
Good, because у діаграмі менше сутностей.
Bad, because у майбутньому, якщо вішліст отримає атрибути (наприклад, дату додавання), зв'язок доведеться перетворити на асоціативну сутність.
Confirmation

У model.mmd немає сутностей Wishlist і Prod_Tag, а є зв'язки Customer }o--o{ Product і Product }o--o{ Tags.

Pros and Cons of the Options
Окремі сутності Wishlist і Prod_Tag
Good, because відповідає тому, як це зберігатиметься в БД.
Bad, because це сполучні таблиці без атрибутів, а завдання їх забороняє.
Прямий зв'язок }o--o{
Good, because відповідає вимозі та рівню абстракції ER-моделі.
Neutral, because вимагає перетворення, якщо з'являться атрибути зв'язку.

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