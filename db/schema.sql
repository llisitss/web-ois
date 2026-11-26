CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email           text NOT NULL,
    full_name       text NOT NULL,
    password_hash   text NOT NULL,
    role            text NOT NULL DEFAULT 'student'
        CHECK (role IN ('student', 'organizer', 'admin')),
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE clubs (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            text NOT NULL UNIQUE,
    slug            text NOT NULL UNIQUE,
    description     text NOT NULL DEFAULT ''
);

CREATE TABLE club_organizers (
    user_id         bigint NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    club_id         bigint NOT NULL REFERENCES clubs (id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, club_id)
);

CREATE TABLE rooms (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            text NOT NULL UNIQUE,
    building        text NOT NULL,
    capacity        integer NOT NULL CHECK (capacity > 0)
);

CREATE TABLE events (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    club_id         bigint NOT NULL REFERENCES clubs (id),
    room_id         bigint NOT NULL REFERENCES rooms (id),
    created_by      bigint NOT NULL REFERENCES users (id),
    title           text NOT NULL CHECK (length(title) BETWEEN 3 AND 200),
    description     text NOT NULL DEFAULT '',
    starts_at       timestamptz NOT NULL,
    ends_at         timestamptz NOT NULL,
    capacity        integer NOT NULL CHECK (capacity > 0),
    status          text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'published', 'rejected', 'cancelled')),
    reject_reason   text,
    cover_url       text,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT events_time_order CHECK (ends_at > starts_at)
);

CREATE INDEX events_starts_at_idx ON events (starts_at);
CREATE INDEX events_ends_at_idx ON events (ends_at);

CREATE TABLE registrations (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id        bigint NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    user_id         bigint NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX registrations_one_active on registrations (event_id, user_id)
    WHERE status = 'active';


-- Теги. Много ко многим: сам тег живёт отдельно от мероприятий, связь — в event_tags.
CREATE TABLE tags (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            text NOT NULL,

    CONSTRAINT tags_name_unique UNIQUE (name),
    CONSTRAINT tags_name_not_empty CHECK (btrim(name) <> '')
);

-- Связь мероприятия с тегом. Удалили мероприятие — связь исчезает вместе с ним
-- (ON DELETE CASCADE), тег как справочник при этом остаётся.
CREATE TABLE event_tags (
    event_id        bigint NOT NULL,
    tag_id          bigint NOT NULL,

    CONSTRAINT event_tags_event_fk FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE,
    CONSTRAINT event_tags_tag_fk FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE,
    -- один тег на одном мероприятии не ставится дважды
    CONSTRAINT event_tags_event_tag_unique UNIQUE (event_id, tag_id)
);

-- Поиск мероприятий по тегу: сам уникальный ключ идёт (event_id, tag_id), поэтому
-- для условия WHERE tag_id = ... нужен отдельный индекс по второй колонке.
CREATE INDEX event_tags_by_tag_idx ON event_tags (tag_id);


-- Отзывы студента на мероприятие.
CREATE TABLE reviews (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id        bigint NOT NULL,
    student_id      bigint NOT NULL,
    rating          integer NOT NULL,
    comment         text,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT reviews_event_fk FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE,
    CONSTRAINT reviews_student_fk FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT reviews_rating_between_1_and_5 CHECK (rating BETWEEN 1 AND 5),
    -- один студент не может оставить на мероприятие больше одного отзыва
    CONSTRAINT reviews_one_review_per_student UNIQUE (event_id, student_id)
);
