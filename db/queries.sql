-- Запросы к практике 3. Ожидаемые результаты — для демо-данных из seed.sql.


-- 1. Каждый клуб и число его опубликованных мероприятий.
-- Клубы без афиши должны остаться в результате с нулём, поэтому клуб left join мероприятий,
-- а условие status = 'published' стоит в ON: в WHERE оно отбросило бы строку с NULL
-- и клуб исчез бы из выборки. count(e.id) считает только не пустые, то есть 0 для такого клуба.
SELECT c.name,
       count(e.id) AS published
FROM clubs c
         LEFT JOIN events e ON e.club_id = c.id AND e.status = 'published'
GROUP BY c.id, c.name
ORDER BY published DESC, c.name;

-- 1: IT-клуб 2, Шахматный клуб 1, Киноклуб 0


-- 2. Каждый организатор и клубы, которые он ведёт, одной строкой через запятую.
-- string_agg собирает названия внутри группы (по организатору); порядок склейки задаёт
-- ORDER BY внутри агрегата, а не общий ORDER BY запроса.
SELECT u.full_name,
       string_agg(c.name, ', ' ORDER BY c.name) AS clubs
FROM users u
         JOIN club_organizers co ON co.user_id = u.id
         JOIN clubs c ON c.id = co.club_id
GROUP BY u.id, u.full_name
ORDER BY u.full_name;

-- 2: Глеб Ферзев | Шахматный клуб, Ирина Котова | IT-клуб, Киноклуб


-- 3. Пользователи с двумя и больше активными записями и число этих записей.
-- Отменённые записи отсекаются до группировки (ON), а условие на количество — после,
-- через HAVING: агрегат в WHERE использовать нельзя.
SELECT u.full_name,
       count(r.id) AS count
FROM users u
         JOIN registrations r ON r.user_id = u.id AND r.status = 'active'
GROUP BY u.id, u.full_name
HAVING count(r.id) >= 2
ORDER BY count DESC, u.full_name;

-- 3: Анна Смирнова 2, Борис Ковалёв 2


-- 4. Загрузка каждой аудитории в ноябре 2026: часы по мероприятиям на модерации
-- и опубликованным, отменённые не считаются. Границы месяца срезаются greatest/least,
-- чтобы мероприятие, начатое в октябре или закончившееся в декабре, посчиталось только
-- своей частью ноября. Аудитория без мероприятий остаётся с нулём из-за left join.
WITH november AS (
    SELECT e.room_id,
           extract(epoch FROM least(e.ends_at, timestamptz '2026-12-01 00:00+07')
                                - greatest(e.starts_at, timestamptz '2026-11-01 00:00+07')) AS seconds
    FROM events e
    WHERE e.status IN ('pending', 'published')
      AND e.starts_at < timestamptz '2026-12-01 00:00+07'
      AND e.ends_at > timestamptz '2026-11-01 00:00+07'
)
SELECT r.name,
       round(coalesce(sum(n.seconds), 0) / 3600, 2)::numeric(7, 2) AS hours
FROM rooms r
         LEFT JOIN november n ON n.room_id = r.id
GROUP BY r.id, r.name
ORDER BY hours DESC, r.name;

-- 4: Ауд. 214 4.75, Ауд. 101 4.00, Коворкинг 2.00


-- 5. Мероприятия с тегом «IT» по времени начала: идём через связующую таблицу
-- event_tags (мероприятие -> тег), сама связь многие-ко-многим нигде не дублируется.
SELECT e.id,
       e.title,
       e.starts_at,
       t.name AS tag
FROM events e
         JOIN event_tags et ON et.event_id = e.id
         JOIN tags t ON t.id = et.tag_id
WHERE t.name = 'IT'
ORDER BY e.starts_at;

-- 5: лекция про Яндекс (1) и мастер-класс по Git (3)
