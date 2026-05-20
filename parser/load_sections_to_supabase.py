import hashlib
import os
from datetime import datetime, timezone
from urllib.parse import urljoin, urlparse

import requests
import trafilatura
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from supabase import create_client, Client


load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise ValueError("Не заданы SUPABASE_URL или SUPABASE_SERVICE_ROLE_KEY в .env")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/131.0.0.0 Safari/537.36"
    )
}

MIN_TEXT_LENGTH = 800
MAX_ARTICLES_PER_SECTION = 12


SECTION_CONFIGS = [
    {
        "source_name": "Naked Science",
        "topic_name": "Космос",
        "list_url": "https://naked-science.ru/article/astronomy",
        "domain": "naked-science.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": ["/article/astronomy"],
    },
    {
        "source_name": "Arzamas",
        "topic_name": "История",
        "list_url": "https://arzamas.academy/mag/history",
        "domain": "arzamas.academy",
        "path_mode": "starts_with",
        "allowed_paths": ["/mag/"],
        "forbidden_exact": [
            "/mag/history",
            "/mag/arts",
        ],
    },
    {
        "source_name": "Arzamas",
        "topic_name": "Искусство",
        "list_url": "https://arzamas.academy/mag/arts",
        "domain": "arzamas.academy",
        "path_mode": "starts_with",
        "allowed_paths": ["/mag/"],
        "forbidden_exact": [
            "/mag/history",
            "/mag/arts",
        ],
    },
    {
        "source_name": "Indicator",
        "topic_name": "Наука",
        "list_url": "https://indicator.ru/",
        "domain": "indicator.ru",
        "path_mode": "contains",
        "allowed_paths": [
            "/article/",
            "/news/",
            "/humanitarian-science/",
            "/medicine/",
            "/engineering-science/",
            "/natural-science/",
        ],
        "forbidden_exact": ["/"],
    },
    {
        "source_name": "Naked Science",
        "topic_name": "Технологии",
        "list_url": "https://naked-science.ru/article/hi-tech",
        "domain": "naked-science.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": ["/article/hi-tech"],
    },
    {
        "source_name": "Naked Science",
        "topic_name": "Природа и животные",
        "list_url": "https://naked-science.ru/tags/priroda",
        "domain": "naked-science.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": ["/tags/priroda", "/tags/zhivotnye"],
    },
    {
        "source_name": "Naked Science",
        "topic_name": "Природа и животные",
        "list_url": "https://naked-science.ru/tags/zhivotnye",
        "domain": "naked-science.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": ["/tags/priroda", "/tags/zhivotnye"],
    },
    {
        "source_name": "b17",
        "topic_name": "Психология",
        "list_url": "https://www.b17.ru/article/",
        "domain": "b17.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": [],
    },
    {
        "source_name": "Naked Science",
        "topic_name": "География",
        "list_url": "https://naked-science.ru/tags/geografiya",
        "domain": "naked-science.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": ["/tags/geografiya"],
    },
    {
        "source_name": "Naked Science",
        "topic_name": "Биология",
        "list_url": "https://naked-science.ru/article/biology",
        "domain": "naked-science.ru",
        "path_mode": "starts_with",
        "allowed_paths": ["/article/"],
        "forbidden_exact": ["/article/biology"],
    },
    {
        "source_name": "Econs",
        "topic_name": "Экономика",
        "list_url": "https://econs.online/articles/ekonomika/",
        "domain": "econs.online",
        "path_mode": "contains",
        "allowed_paths": ["/articles/"],
        "forbidden_exact": ["/articles/ekonomika", "/articles/ekonomika/"],
    },
]


def fetch_html(url: str) -> str | None:
    try:
        response = requests.get(url, headers=HEADERS, timeout=25)
        response.raise_for_status()
        response.encoding = response.apparent_encoding
        return response.text
    except Exception as e:
        print(f"Ошибка загрузки {url}: {e}")
        return None


def normalize_url(base_url: str, href: str) -> str | None:
    if not href:
        return None

    full_url = urljoin(base_url, href)
    parsed = urlparse(full_url)

    if parsed.scheme not in ("http", "https"):
        return None

    cleaned = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"
    return cleaned.rstrip("/")


def path_allowed(path: str, config: dict) -> bool:
    mode = config.get("path_mode", "starts_with")
    allowed_paths = [p.rstrip("/") for p in config.get("allowed_paths", [])]

    if not allowed_paths:
        return True

    if mode == "starts_with":
        return any(path.startswith(prefix) for prefix in allowed_paths)

    if mode == "contains":
        return any(fragment in path for fragment in allowed_paths)

    return False


def is_valid_article_link(url: str, config: dict) -> bool:
    parsed = urlparse(url)

    if config["domain"] not in parsed.netloc:
        return False

    path = parsed.path.rstrip("/")

    forbidden_exact = [p.rstrip("/") for p in config.get("forbidden_exact", [])]
    if path in forbidden_exact:
        return False

    if not path_allowed(path, config):
        return False

    return True


def extract_article_links(config: dict) -> list[str]:
    html = fetch_html(config["list_url"])
    if not html:
        return []

    soup = BeautifulSoup(html, "html.parser")
    links = set()

    for a in soup.find_all("a", href=True):
        href = a.get("href")
        full_url = normalize_url(config["list_url"], href)
        if not full_url:
            continue

        if is_valid_article_link(full_url, config):
            links.add(full_url)

    result = list(links)
    result.sort(key=lambda x: len(urlparse(x).path), reverse=True)

    return result[:MAX_ARTICLES_PER_SECTION]


def make_content_hash(title: str, url: str) -> str:
    raw = f"{title}|{url}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def content_exists(content_hash: str) -> bool:
    response = (
        supabase.table("content")
        .select("content_id")
        .eq("content_hash", content_hash)
        .limit(1)
        .execute()
    )
    return len(response.data) > 0


def clean_article_text(text: str) -> str:
    bad_fragments = [
        "последние комментарии",
        "вы попытались написать",
        "вас забанили",
        "если это ошибка, напишите нам",
        "отдохните немного и вернитесь к нам позже",
        "понятно",
        "понятночто",
        "понятноиз",
        "понятнонаши",
        "понятномы",
        "читайте также",
        "последние материалы",
        "комментарии",
        "поделиться",
        "подписывайтесь",
        "реклама",
    ]

    cleaned_paragraphs = []
    seen = set()

    for paragraph in text.split("\n"):
        p = paragraph.strip()
        if not p:
            continue

        lowered = p.lower()

        if any(fragment in lowered for fragment in bad_fragments):
            continue

        if p in seen:
            continue

        seen.add(p)
        cleaned_paragraphs.append(p)

    return "\n\n".join(cleaned_paragraphs).strip()


def clean_title(raw_title: str | None, url: str) -> str:
    if raw_title and raw_title.strip():
        title = " ".join(raw_title.split()).strip()

        endings_to_remove = [
            " — ECONS.ONLINE",
            " | ECONS.ONLINE",
            " — Econs",
            " | Econs",
            " — Naked Science",
            " | Naked Science",
            " — Habr",
            " | Habr",
            " — Arzamas",
            " | Arzamas",
            " — Indicator",
            " | Indicator",
            " — b17.ru",
            " | b17.ru",
        ]

        for ending in endings_to_remove:
            if title.endswith(ending):
                title = title[: -len(ending)].strip()

        return title[:500]

    parsed = urlparse(url)
    fallback = parsed.path.strip("/").split("/")[-1].replace("-", " ").replace("_", " ")
    return fallback[:500] if fallback else "Без названия"


def should_skip_by_title(title: str) -> bool:
    lowered = title.lower()

    skip_words = [
        "фото",
        "реклам",
        "конкурс",
        "тест",
        "баллистический",
        "ученый совет",
        "сериал",
    ]

    return any(word.lower() in lowered for word in skip_words)


def extract_title_from_soup(soup: BeautifulSoup) -> str | None:
    h1 = soup.find("h1")
    if h1:
        h1_text = h1.get_text(" ", strip=True)
        if h1_text:
            return h1_text

    og_title = soup.find("meta", property="og:title")
    if og_title and og_title.get("content"):
        return og_title["content"].strip()

    if soup.title and soup.title.string:
        return soup.title.string.strip()

    return None


def extract_text_from_container(container) -> str:
    paragraphs = []

    for p in container.find_all("p"):
        text = p.get_text(" ", strip=True)
        if not text:
            continue
        if len(text) < 40:
            continue
        paragraphs.append(text)

    full_text = "\n\n".join(paragraphs).strip()
    return clean_article_text(full_text)


def extract_article_data(url: str) -> tuple[str | None, str | None]:
    parsed = urlparse(url)

    try:
        html = fetch_html(url)
        if not html:
            return None, None

        soup = BeautifulSoup(html, "html.parser")
        title = extract_title_from_soup(soup)

        # --- Econs ---
        if "econs.online" in parsed.netloc:
            article_container = (
                soup.find("article")
                or soup.find("div", class_=lambda x: x and "article" in x.lower())
                or soup.find("section", class_=lambda x: x and "article" in x.lower())
            )

            if not article_container:
                return title, None

            full_text = extract_text_from_container(article_container)

            if len(full_text) < MIN_TEXT_LENGTH:
                return title, None

            return title, full_text

        # --- Naked Science ---
        if "naked-science.ru" in parsed.netloc:
            article_container = (
                soup.find("article")
                or soup.find("div", class_=lambda x: x and ("article" in x.lower() or "content" in x.lower()))
                or soup.find("section", class_=lambda x: x and ("article" in x.lower() or "content" in x.lower()))
                or soup.find("main")
            )

            if not article_container:
                return title, None

            full_text = extract_text_from_container(article_container)

            if len(full_text) < MIN_TEXT_LENGTH:
                return title, None

            return title, full_text

        # --- Arzamas ---
        if "arzamas.academy" in parsed.netloc:
            article_container = (
                soup.find("article")
                or soup.find("main")
                or soup.find("div", class_=lambda x: x and ("article" in x.lower() or "content" in x.lower()))
            )

            if article_container:
                full_text = extract_text_from_container(article_container)

                if len(full_text) >= MIN_TEXT_LENGTH:
                    return title, full_text

            return title, None

        # --- b17 ---
        if "b17.ru" in parsed.netloc:
            article_container = (
                soup.find("article")
                or soup.find("div", class_=lambda x: x and ("article" in x.lower() or "content" in x.lower() or "post" in x.lower()))
                or soup.find("main")
            )

            if article_container:
                full_text = extract_text_from_container(article_container)

                if len(full_text) >= MIN_TEXT_LENGTH:
                    return title, full_text

            return title, None

        # --- Indicator и fallback для остальных ---
        downloaded = trafilatura.fetch_url(url)
        if not downloaded:
            return title, None

        text = trafilatura.extract(
            downloaded,
            include_links=False,
            include_formatting=False,
        )

        if not text:
            return title, None

        cleaned_text = clean_article_text(text.strip())

        if len(cleaned_text) < MIN_TEXT_LENGTH:
            return title, None

        return title, cleaned_text

    except Exception as e:
        print(f"Ошибка извлечения статьи {url}: {e}")
        return None, None


def get_topic_id_by_name(topic_name: str) -> int:
    response = (
        supabase.table("topics")
        .select("topic_id, name")
        .eq("name", topic_name)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise ValueError(f"Тема '{topic_name}' не найдена в таблице topics")

    return response.data[0]["topic_id"]


def get_source_id_by_name(source_name: str) -> int:
    response = (
        supabase.table("sources")
        .select("source_id, name")
        .eq("name", source_name)
        .limit(1)
        .execute()
    )

    if not response.data:
        raise ValueError(f"Источник '{source_name}' не найден в таблице sources")

    return response.data[0]["source_id"]


def insert_content(
    source_id: int,
    title: str,
    text: str,
    url: str,
    content_hash: str,
) -> int:
    response = (
        supabase.table("content")
        .insert({
            "source_id": source_id,
            "title": title[:500],
            "text": text,
            "url": url[:500],
            "content_hash": content_hash,
            "published_at": datetime.now(timezone.utc).isoformat(),
        })
        .execute()
    )

    return response.data[0]["content_id"]


def link_content_to_topic(content_id: int, topic_id: int) -> None:
    existing = (
        supabase.table("content_topics")
        .select("content_id, topic_id")
        .eq("content_id", content_id)
        .eq("topic_id", topic_id)
        .limit(1)
        .execute()
    )

    if existing.data:
        return

    supabase.table("content_topics").insert({
        "content_id": content_id,
        "topic_id": topic_id,
    }).execute()


def process_section(config: dict) -> None:
    print(f"\n{config['topic_name']} | {config['list_url']}")

    topic_id = get_topic_id_by_name(config["topic_name"])
    source_id = get_source_id_by_name(config["source_name"])

    article_links = extract_article_links(config)

    if not article_links:
        print("Ссылки на статьи не найдены.")
        return

    print(f"Найдено ссылок: {len(article_links)}")

    added_count = 0

    for article_url in article_links:
        title, text = extract_article_data(article_url)

        if not text:
            print(f"  Пропуск (нет нормального текста): {article_url}")
            continue

        title = clean_title(title, article_url)

        if should_skip_by_title(title):
            print(f"  Пропуск (неподходящий заголовок): {title}")
            continue

        content_hash = make_content_hash(title, article_url)

        if content_exists(content_hash):
            print(f"  Уже есть: {title}")
            continue

        try:
            content_id = insert_content(
                source_id=source_id,
                title=title,
                text=text,
                url=article_url,
                content_hash=content_hash,
            )

            link_content_to_topic(content_id, topic_id)

            added_count += 1
            print(f"  Добавлено: {title}")

        except Exception as e:
            print(f"  Ошибка записи статьи '{title}': {e}")

    print(f"Итого добавлено по разделу: {added_count}")


def main():
    print("Старт загрузки статей по тематическим разделам...")

    for config in SECTION_CONFIGS:
        try:
            process_section(config)
        except Exception as e:
            print(f"Ошибка обработки раздела {config['list_url']}: {e}")

    print("\nЗагрузка завершена.")


if __name__ == "__main__":
    main()