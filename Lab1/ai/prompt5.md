Питання:
Згенеруй Mermaid erDiagram по моєму spec.md

1. Домен

Онлайн-зоомагазин: клієнти купують товари, оформлюють замовлення з оплатою та доставкою, залишають відгуки. Клієнт може мати домашніх тварин і залишати у відгуку інформацію про них. У відгуку зберігається стан тварини на момент написання.

2. Сутності й атрибути

1. Customer: `customer_id` (PK, int), `name` (varchar), `surname` (varchar), `email` (varchar), `phone` (varchar), `zip_code` (varchar).
2. Pet: `pet_id` (PK, int), `customer_id` (FK, int), `name` (varchar), `species` (varchar), `breed` (varchar), `gender` (varchar), `birth_date` (date), `special_needs` (varchar).
3. Product: `prod_id` (PK, int), `category_id` (FK, int), `supplier_id` (FK, int), `title` (varchar), `price` (decimal), `stock` (int).
4. Category: `category_id` (PK, int), `name` (varchar).
5. Supplier: `supplier_id` (PK, int), `name` (varchar), `address` (varchar), `contact` (varchar).
6. Tags: `tag_id` (PK, int), `name` (varchar).
7. Prod_Tag: `tag_id` (PK/FK, int), `prod_id` (PK/FK, int).
8. Wishlist: `customer_id` (PK/FK, int), `prod_id` (PK/FK, int).
9. Orders: `order_id` (PK, int), `customer_id` (FK, int), `status` (varchar), `date` (date).
10. Order_Prod: `order_id` (PK/FK, int), `prod_id` (PK/FK, int), `quantity` (int), `price_at_purchase` (decimal).
11. Delivery: `del_id` (PK, int), `order_id` (FK, int), `tracking_num` (varchar), `status` (varchar), `date` (date), `address` (varchar).
12. Payment: `pay_id` (PK, int), `order_id` (FK, int), `amount` (decimal), `status` (varchar), `date` (date).
13. Review: `review_id` (PK, int), `customer_id` (FK, int), `pet_id` (FK, int), `prod_id` (FK, int), `rating` (int), `text` (varchar).

3. Зв'язки

1. Customer 1 : N Pet. Клієнт має 0..N тварин. Тварина належить рівно одному клієнту.
2. Customer 1 : N Orders. Клієнт робить 0..N замовлень. Замовлення належить рівно одному клієнту.
3. Customer 1 : N Review. Клієнт пише 0..N відгуків. Відгук має рівно одного автора.
4. Customer 1 : N Wishlist. Клієнт має 0..N записів у вішлісті. Запис належить рівно одному клієнту.
5. Product 1 : N Wishlist. Товар може бути у 0..N записах вішліста. Запис стосується рівно одного товару.
6. Pet 1 : N Review. Тварина фігурує у 0..N відгуків. Відгук стосується рівно однієї тварини.
7. Product 1 : N Review. Товар має 0..N відгуків. Відгук стосується рівно одного товару.
8. Category 1 : N Product. Категорія містить 0..N товарів. Товар належить рівно одній категорії.
9. Supplier 1 : N Product. Постачальник постачає 0..N товарів. Товар має рівно одного постачальника.
10. Product 1 : N Prod_Tag. Товар має 0..N записів тегів. Запис стосується рівно одного товару.
11. Tags 1 : N Prod_Tag. Тег використовується у 0..N записах. Запис стосується рівно одного тега.
12. Orders 1 : N Order_Prod. Замовлення містить 1..N позицій. Позиція належить рівно одному замовленню.
13. Product 1 : N Order_Prod. Товар є у 0..N позиціях. Позиція стосується рівно одного товару. Зберігає quantity і price_at_purchase на випадок зміни ціни.
14. Orders 1 : 0..1 Payment. Замовлення має 0..1 оплату. Оплата належить рівно одному замовленню.
15. Orders 1 : 0..1 Delivery. Замовлення має 0..1 доставку. Доставка належить рівно одному замовленню.

Відповідь:
erDiagram
    Customer {
        int customer_id PK
        string name
        string surname
        string email
        string phone
        string zip_code
    }
    Pet {
        int pet_id PK
        int customer_id FK
        string name
        string species
        string breed
        string gender
        date birth_date
        string special_needs
    }
    Supplier {
        int supplier_id PK
        string name
        string address
        string contact
    }
    Product {
        int prod_id PK
        int category_id FK
        int supplier_id FK
        string title
        decimal price
        int stock
    }
    Orders {
        int order_id PK
        int customer_id FK
        string status
        date date
    }
    Delivery {
        int del_id PK
        int order_id FK
        string tracking_num
        string status
        date date
        string address
    }
    Review {
        int review_id PK
        int customer_id FK
        int pet_id FK
        int prod_id FK
        int rating
        string text
    }
    Category {
        int category_id PK
        string name
    }
    Tags {
        int tag_id PK
        string name
    }
    Prod_Tag {
        int tag_id PK, FK
        int prod_id PK, FK
    }
    Wishlist {
        int customer_id PK, FK
        int prod_id PK, FK
    }
    Order_Prod {
        int prod_id PK, FK
        int order_id PK, FK
        int quantity
        decimal price_at_purchase
    }
    Payment {
        int pay_id PK
        int order_id FK
        decimal amount
        string status
        date date
    }

    Customer ||--o{ Pet : "має домашніх тварин"
    Customer ||--o{ Orders : "робить замовлення"
    Customer ||--o{ Review : "пише відгуки"
    Product ||--o{ Review : "має відгуки"
    Customer ||--o{ Wishlist : "додає до обраного"
    Product ||--o{ Wishlist : "зберігається в обраному"
    Category ||--o{ Product : "містить товари"
    Supplier ||--o{ Product : "постачає"
    Product ||--o{ Prod_Tag : "має теги"
    Tags ||--o{ Prod_Tag : "належить до тегу"
    Orders ||--|{ Order_Prod : "містить позиції"
    Product ||--o{ Order_Prod : "замовлено в позиціях"
    Pet ||--o{ Review : "згадується у відгуку"
    Orders ||--o| Payment : "оплачується через"
    Orders ||--o| Delivery : "доставляється через"