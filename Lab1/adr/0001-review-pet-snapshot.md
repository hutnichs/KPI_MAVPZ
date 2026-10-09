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