from fastapi import APIRouter
from src.database import DBSession
from src.services.reset import reset_user_preferences

router = APIRouter(
    prefix="/reset",
    tags=["reset"],
    responses={404: {"description": "Not found"}},
)


@router.post("", response_model=dict)
async def reset(db: DBSession):

    reset_status = await reset_user_preferences(db=db)

    if reset_status is True:
        return {
            "message": "Database reset successful",
        }

    elif reset_status is False:
        return {
            "message": "Database reset failed",
        }
