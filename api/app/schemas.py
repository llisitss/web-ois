from pydantic import AwareDatetime, BaseModel, Field, field_validator, model_validator


class Club(BaseModel):
    """Как отдаём клуб клиенту: id назначает сервер, клиент его не выбирает."""

    id: int = Field(examples=[4])
    name: str = Field(examples=["Клуб робототехники"])


class ClubCreate(BaseModel):
    """Входная модель: название клуба для создания и для переименования."""

    name: str = Field(
        description="Название клуба от 2 до 100 символов. Пробелы по краям в название не входят.",
        examples=["Клуб робототехники", "   Киноклуб   "],
    )

    @field_validator("name")
    @classmethod
    def tidy_name(cls, raw: str) -> str:
        # Сначала убираем пробелы по краям, потом проверяем длину: « a » станет «a» и не пройдёт min_length.
        name = raw.strip()
        if len(name) < 2:
            raise ValueError("Название клуба должно быть не короче 2 символов")
        if len(name) > 100:
            raise ValueError("Название клуба должно быть не длиннее 100 символов")
        return name


class Room(BaseModel):
    id: int
    name: str
    building: str
    capacity: int


class EventBase(BaseModel):
    title: str = Field(min_length=3, max_length=200, examples=["Как устроен поиск Яндекса"])
    description: str = Field(default="", max_length=5000)
    club_id: int = Field(examples=[1])
    room_id: int = Field(examples=[1])
    starts_at: AwareDatetime = Field(examples=["2026-11-27T18:00:00+07:00"])
    ends_at: AwareDatetime = Field(examples=["2026-11-27T20:00:00+07:00"])
    capacity: int = Field(gt=0, le=1000, examples=[30])


class EventCreate(EventBase):
    @model_validator(mode="after")
    def check_time_order(self):
        # BR-7: окончание позже начала
        if self.ends_at <= self.starts_at:
            raise ValueError("Время окончания должно быть позже времени начала")
        return self


class EventUpdate(BaseModel):
    """Все поля необязательны: меняется только то, что прислали."""

    title: str | None = Field(default=None, min_length=3, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    room_id: int | None = None
    starts_at: AwareDatetime | None = None
    ends_at: AwareDatetime | None = None
    capacity: int | None = Field(default=None, gt=0, le=1000)


class EventRead(EventBase):
    id: int


class EventPage(BaseModel):
    items: list[EventRead]
    total: int
    page: int
    size: int


class ErrorResponse(BaseModel):
    detail: str = Field(examples=["Мероприятие не найдено"])
