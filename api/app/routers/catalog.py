from typing import Annotated

from fastapi import APIRouter, HTTPException, Path, status

from app import storage
from app.schemas import Club, ClubCreate, ErrorResponse, Room

router = APIRouter(prefix="/api", tags=["Справочники"])

CLUB_NOT_FOUND = {404: {"model": ErrorResponse, "description": "Клуба с таким id нет"}}
NAME_TAKEN = {409: {"model": ErrorResponse, "description": "Такое название уже занято другим клубом"}}
BAD_NAME = {
    422: {
        "model": ErrorResponse,
        "description": (
            "Название от 2 до 100 символов по уже очищенному тексту; строка короче или длиннее — 422. "
            "Сюда же уходит нечисловой id клуба в пути."
        ),
    }
}
CLUB_ID_DOC = Path(description="Идентификатор клуба", examples=[3])
ClubId = Annotated[int, CLUB_ID_DOC]


def find_club(club_id: int) -> dict:
    """Клуб по id или 404."""
    club = storage.CLUBS.get(club_id)
    if club is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Клуб {club_id} не найден")
    return club


def club_with_same_name(name: str, except_id: int | None = None) -> dict | None:
    """Клуб-однофамилец: названия сравниваем без учёта регистра.

    Клуб `except_id` (тот, который переименовываем) в сравнение не входит, иначе
    нельзя было бы поменять только регистр букв своего названия.
    """
    wanted = name.casefold()
    return next(
        (c for c in storage.CLUBS.values() if c["id"] != except_id and c["name"].casefold() == wanted),
        None,
    )


def club_events(club_id: int) -> list[dict]:
    """Мероприятия, закреплённые за клубом."""
    return [e for e in storage.EVENTS.values() if e["club_id"] == club_id]


@router.get("/clubs", response_model=list[Club], summary="Клубы")
def list_clubs():
    return list(storage.CLUBS.values())


@router.get(
    "/clubs/{club_id}",
    response_model=Club,
    responses=CLUB_NOT_FOUND,
    summary="Один клуб",
    description="Ищет клуб по идентификатору; название в запросе не участвует.",
)
def get_club(club_id: ClubId):
    return find_club(club_id)


@router.post(
    "/clubs",
    response_model=Club,
    status_code=status.HTTP_201_CREATED,
    summary="Создать клуб",
    description=(
        "Создаёт клуб с названием из тела запроса: пробелы по краям обрезаются, "
        "проверяется длина от 2 до 100 символов. Идентификатор выдаёт счётчик — так же, "
        "как у мероприятий. Название не должно совпадать (без учёта регистра) с уже имеющимся."
    ),
    responses={**NAME_TAKEN, **BAD_NAME},
)
def create_club(payload: ClubCreate):
    taken = club_with_same_name(payload.name)
    if taken is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Такое название уже занято: клуб {taken['id']} — «{taken['name']}»",
        )
    club = {"id": storage.next_club_id(), "name": payload.name}
    storage.CLUBS[club["id"]] = club
    return club


@router.patch(
    "/clubs/{club_id}",
    response_model=Club,
    summary="Переименовать клуб",
    description=(
        "Заменяет название клуба. Строка проходит те же проверки, что и при создании, "
        "и не должна совпадать без учёта регистра с названием другого клуба."
    ),
    responses={**CLUB_NOT_FOUND, **NAME_TAKEN, **BAD_NAME},
)
def rename_club(club_id: ClubId, payload: ClubCreate):
    club = find_club(club_id)
    taken = club_with_same_name(payload.name, except_id=club_id)
    if taken is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Название «{payload.name}» уже у клуба {taken['id']} — «{taken['name']}»",
        )
    club["name"] = payload.name
    return club


@router.delete(
    "/clubs/{club_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Удалить клуб",
    description=(
        "Убирает клуб из справочника. Клуб, к которому привязаны мероприятия, не удаляем: "
        "сначала нужно удалить или перевести эти мероприятия — их количество называется в 409."
    ),
    responses={
        **CLUB_NOT_FOUND,
        **BAD_NAME,
        409: {"model": ErrorResponse, "description": "У клуба есть мероприятия — удаление запрещено"},
    },
)
def delete_club(club_id: ClubId):
    find_club(club_id)
    related = club_events(club_id)
    if related:
        ids = ", ".join(str(e["id"]) for e in related)
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Клуб занят мероприятиями: {len(related)} (ids: {ids})",
        )
    del storage.CLUBS[club_id]


@router.get("/rooms", response_model=list[Room], summary="Аудитории")
def list_rooms():
    return list(storage.ROOMS.values())
