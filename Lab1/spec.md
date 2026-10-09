1. Домен

Онлайн-зоомагазин: клієнти купують товари, оформлюють замовлення з оплатою та доставкою, залишають відгуки. Клієнт може мати домашніх тварин і залишати у відгуку інформацію про них. У відгуку зберігається стан тварини на момент написання.

2. Сутності й атрибути

1. Customer: `customer_id` (PK, int), `name` (varchar), `surname` (varchar), `email` (varchar), `phone` (varchar), `zip_code` (varchar), `is_deleted` (boolean).
2. Pet: `pet_id` (PK, int), `customer_id` (FK, int), `name` (varchar), `species` (varchar), `breed` (varchar), `gender` (varchar), `birth_date` (date), `special_needs` (varchar), `is_deleted` (boolean).
3. Product: `prod_id` (PK, int), `category_id` (FK, int), `supplier_id` (FK, int), `title` (varchar), `price` (decimal), `stock` (int).
4. Prod_Img: pi_id (PK, int), prod_id (FK, int), img_url (varchar), is_main (boolean).
5. Category: `category_id` (PK, int), `name` (varchar).
6. Supplier: `supplier_id` (PK, int), `name` (varchar), `address` (varchar), `contact` (varchar).
7. Tags: `tag_id` (PK, int), `name` (varchar).
8. Orders: `order_id` (PK, int), `customer_id` (FK, int), `status` (varchar), `date` (date).
9. Order_Prod: `order_id` (PK/FK, int), `prod_id` (PK/FK, int), `quantity` (int), `price_at_purchase` (decimal).
10. Delivery: `del_id` (PK, int), `order_id` (FK, int), `tracking_num` (varchar), `status` (varchar), `date` (date), `address` (varchar).
11. Payment: `pay_id` (PK, int), `order_id` (FK, int), `amount` (decimal), `status` (varchar), `date` (date).
12. Review: `review_id` (PK, int), `customer_id` (FK, int), `pet_id` (FK, int), `prod_id` (FK, int), `rating` (int), `text` (varchar) `pet_info` (varchar).
13. Review_Pet_Snapshot: `pet_id` (PK/FK, int), `review_id` (PK/FK, int), `name` (varchar), `species` (varchar), `breed` (varchar), `gender` (varchar), `birth_date` (date), `special_needs` (varchar) (збереження стану тварини на момент написання відгуку)..
14. Employee: `empl_id` (PK, int), `name` (varchar), `surname` (varchar), `email` (varchar), `phone` (varchar), `role` (varchar), `hired_at` (date), `is_deleted` (boolean).

3. Зв'язки

1. Customer 1 : N Pet. Клієнт має 0..N тварин. Тварина належить рівно одному клієнту.
2. Customer 1 : N Orders. Клієнт робить 0..N замовлень. Замовлення належить рівно одному клієнту.
3. Customer 1 : N Review. Клієнт пише 0..N відгуків. Відгук має рівно одного автора.
4. Customer M : N Product (вішліст). Клієнт додає у вішліст 0..N товарів. Товар може бути у вішлісті 0..N клієнтів. Зв'язок без власних атрибутів, тому без асоціативної сутності. 
5. Pet 1 : N Review_Pet_Snapshot. Тварина має 0..N снапшотів. Снапшот стосується рівно однієї тварини.
6. Review 1 : N Review_Pet_Snapshot. Відгук містить 0..N снапшотів. Снапшот належить рівно одному відгуку. Тут асоціативна сутність між Review і Pet, щоб зберегти інформацію, якщо вона зміниться або її буде позначено видаленою.
7. Product 1 : N Review. Товар має 0..N відгуків. Відгук стосується рівно одного товару.
8. Category 1 : N Product. Категорія містить 0..N товарів. Товар належить рівно одній категорії.
9. Supplier 1 : N Product. Постачальник постачає 0..N товарів. Товар має рівно одного постачальника.
10. Product 1 : N Prod_Img. Товар має 0..N зображень. Зображення належить рівно одному товару.
11. Product M : N Tags. Товар має 0..N тегів. Тег стосується 0..N товарів.
12. Orders 1 : N Order_Prod. Замовлення містить 1..N позицій. Позиція належить рівно одному замовленню.
13. Product 1 : N Order_Prod. Товар є у 0..N позиціях. Позиція стосується рівно одного товару. Асоціативна сутність з quantity і price_at_purchase на випадок зміни ціни.
14. Orders 1 : N Payment. Замовлення має 0..N оплат (повторні спроби, часткова оплата). Оплата належить рівно одному замовленню.
15. Orders 1 : N Delivery. Замовлення має 0..N доставок. Доставка належить рівно одному замовленню.
16. Employee 1 : N Product (added_by). Працівник додає 0..N товарів. товар додано рівно одним працівником.
17. Employee 0..1 : N Orders (processed_by). Працівник обробляє 0..N замовлень. Замовлення має 0..1 працівника, поки його не призначено.
18. Employee 0..1 : N Delivery (shipped_by). Працівник відправляє 0..N доставок. Доставка має 0..1 відправника, поки не відправлено.

4. Критерії прийняття

AC-1 (ключі). Кожна сутність має PK. Кожен FK з розділу 2 відповідає зв'язку з розділу 3, і кожен зв'язок 1:N має відповідний FK.

AC-2 (типи id). Усі PK і FK мають тип int, без винятків.

AC-3 (іменування). Ідентифікатори пишуться lowercase snake_case із суфіксом _id. FK має ту саму назву, що й PK, на який посилається. Виняток: рольові FK added_by, processed_by, shipped_by посилаються на Employee.empl_id. Назви полів у діаграмі збігаються зі spec.md буква в букву.

AC-4 (3НФ). Кожен неключовий атрибут залежить від ключа, усього ключа й нічого, крім ключа. Єдині винятки описані в розділі 5.

AC-5 (кардинальності). Кардинальність і обов'язковість кожного зв'язку в діаграмі (0..N, 1..N, 0..1, рівно 1) збігаються з розділом 3.

AC-6 (відтворюваність). Діаграма відповідає spec.md. Розбіжності виправляються зміною spec.md/критеріїв окремим комітом, а не ручним патчем діаграми.

AC-7 (м'яке видалення). Сутності, на які посилається історія (Customer, Pet, Supplier, Product, Review, Employee), позначаються is_deleted, а не видаляються фізично.

AC-8 (домен значень). rating — ціле від 1 до 5.

AC-9 (м'яке видалення). Сутності, на які посилається історія замовлень чи відгуків (Customer, Pet, Product, Supplier, Review, Employee), мають is_deleted і не видаляються фізично. Решта сутностей його не мають.

5. Свідомі винятки з 3НФ
1. Review_Pet_Snapshot дублює атрибути Pet. Тварина з часом змінюється або видаляється, а відгук має зберегти її стан на момент написання. Дублювання навмисне.
2. Order_Prod.price_at_purchase дублює Product.price. Ціна товару змінюється, а сума минулого замовлення не повинна.