import ast
import csv
import hashlib
import json
import textwrap

import json5
import regex as re
from mem0 import Memory
from sqlalchemy.ext.asyncio import AsyncSession
from src.logging import logger
from src.models.products import PersonalizedProductSection
from src.repository.personalized_product_section import PersonalizedProductRepository
from src.schemas.agents import UserQueryAgentResponse
from src.schemas.enums import StatusEnum


async def add_user_preference_to_memory_during_migration(
    data: list, memory: Memory
) -> None:
    for row in data:
        user_id = row.get("id")
        user_preferences = row.get("preferences")
        for _, preference in enumerate(user_preferences, start=1):
            logger.info(
                f"Adding user preference '{preference}' for user_id: {user_id} in memory",
            )
            output = await memory.add(
                messages=preference,
                user_id=str(user_id),
            )
            logger.info(f"Output from mem0={str(output)}")


def load_csv_data(file_path: str) -> list:
    with open(file_path, "r", encoding="utf-8") as file:
        reader = list(csv.DictReader(file))
        data = [parse_json_fields(row) for row in reader]
    return data


def parse_json_fields(row: dict) -> dict:
    for key, value in row.items():
        try:
            row[key] = json.loads(value)
        except json.JSONDecodeError:
            pass
    return row


def parse_json(json_str: str) -> dict:
    try:
        return json.loads(json_str)
    except json.JSONDecodeError:
        return {}


def get_user_session_key(user_id: int) -> str:
    return hashlib.sha256(
        f"user_id={user_id}".encode(),
    ).hexdigest()


def get_user_chat_agent_response(agent_response: UserQueryAgentResponse) -> dict:
    """
    Only return attributes that are not None.
    """
    return {
        key: getattr(agent_response, key) for key in agent_response.model_fields_set
    }


def extract_json_blocks(content: str) -> list[str]:
    """
    Extracts all top-level JSON-like blocks ({...} or [...]) from a string,
    including nested blocks.
    """
    blocks = []
    stack = []
    start_idx = None
    for idx, char in enumerate(content):
        if char in "{[":
            if not stack:
                start_idx = idx
            stack.append(char)
        elif char in "}]":
            if stack:
                open_char = stack.pop()
                # Check for matching pairs
                if (open_char == "{" and char != "}") or (
                    open_char == "[" and char != "]"
                ):
                    continue  # ignore mismatched
                if not stack and start_idx is not None:
                    blocks.append(content[start_idx : idx + 1])  # noqa: E203
                    start_idx = None
    return blocks


def print_pretty_with_embedded_json(content: str) -> str:
    """
    Prettifies content for API response.

    1. If whole string is valid JSON -> json.dumps formatting.
    2. Else, pretty print all embedded `{...}` or `[...]` blocks.
    3. Safe for dict-like strings (LLM outputs, logs, traces).
    """
    # Case 1: Whole string is valid JSON
    try:
        parsed = json.loads(content)
        return json.dumps(parsed, indent=4, ensure_ascii=False)
    except (json.JSONDecodeError, TypeError):
        pass

    content = re.sub(r"\s+", " ", content)
    blocks = extract_json_blocks(content)

    for block in blocks:
        is_parsed = True
        pretty_block = re.sub(r"(\\n|\n)", "", block)
        pretty_block = re.sub(r"\\", "", pretty_block)

        try:
            pretty_block = json5.loads(pretty_block)
        except Exception:
            pretty_block, is_parsed = _parse_using_literal_eval(pretty_block)

        if is_parsed and isinstance(pretty_block, dict):
            for key, value in pretty_block.items():
                if isinstance(value, str):
                    pretty_block[key] = print_pretty_with_embedded_json(value)
            pretty_block = json.dumps(pretty_block, indent=4, ensure_ascii=False)
        elif isinstance(pretty_block, str):
            pretty_block = _parse_json_using_regex(pretty_block)
        elif isinstance(pretty_block, list):
            pretty_block = json.dumps(pretty_block, indent=4, ensure_ascii=False)
        content = content.replace(block, "\n" + pretty_block + "\n")

    return content


def _parse_using_literal_eval(content: str) -> tuple[dict | str, bool]:
    """
    Parses a string using ast.literal_eval.
    Handles single quotes and unquoted keys.
    """
    is_parsed = True
    try:
        content = ast.literal_eval(content)
    except Exception:
        is_parsed = False

    return content, is_parsed


def _parse_json_using_regex(content: str) -> tuple[dict | str, bool]:
    """
    Parses a string using regex.
    Handles single quotes and unquoted keys.
    """
    # Case 1: Whole string is valid JSON
    try:
        parsed = json.loads(content)
        return json.dumps(parsed, indent=2, ensure_ascii=False)
    except (json.JSONDecodeError, TypeError):
        pass

    # Case 2: Format dict-like or list-like blocks
    blocks = re.findall(r"(\{.*?\}|\[.*?\])", content, re.DOTALL)

    for block in blocks:
        pretty_block = re.sub(r",\s*", ",\n", block)
        pretty_block = re.sub(r"([\{\[])\s*", r"\1\n", pretty_block)
        pretty_block = re.sub(r"\s*([\}\]])", r"\n\1", pretty_block)
        pretty_block = textwrap.indent(pretty_block, "   ")
        content = content.replace(block, pretty_block)
    return content


def format_variants(variants) -> list:
    formatted_variants = []
    for variant in variants:
        variant_data = {
            "price": f"${variant.price}",
            "in_stock": variant.in_stock,
        }
        for attribute in variant.attributes:
            variant_data[attribute.attribute_name] = attribute.attribute_value
        formatted_variants.append(variant_data)

    return formatted_variants


async def set_personalization_status(
    db: AsyncSession,
    user_id: int,
    product_id: int,
    status: StatusEnum,
) -> None:
    """Set the status of the personalized product section."""
    personalized_section = PersonalizedProductSection(
        product_id=product_id,
        user_id=user_id,
        status=status,
    )
    await PersonalizedProductRepository(db).add_or_update(personalized_section)
    logger.info(
        "Personalized product section status set to running for user_id=%s, product_id=%s",
        user_id,
        product_id,
    )


def convert_trace_id_to_hex(trace_id):
    """
    Convert the trace ID to a hexadecimal string as this is used to fetch the trace data.
    Args:
        trace_id (int): The trace ID to convert.
    Returns:
        str: The hexadecimal representation of the trace ID with 0x prefix removed.
    """

    hexed_tace_id = hex(int(trace_id))[2:]
    padded_trace_id = hexed_tace_id.zfill(32)

    return padded_trace_id
