import json
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone

BASE = "http://127.0.0.1:8080/api"
EMAIL = "test@fefo.local"
PASSWORD = "TestPassword2026!"

def request(path, method="GET", data=None):
    body = None if data is None else json.dumps(data).encode()
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token

    req = urllib.request.Request(
        BASE + path,
        data=body,
        headers=headers,
        method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        message = e.read().decode()
        raise RuntimeError(f"{method} {path}: HTTP {e.code}: {message}")

login = urllib.request.Request(
    BASE + "/auth/login",
    data=json.dumps({
        "email": EMAIL,
        "password": PASSWORD
    }).encode(),
    headers={"Content-Type": "application/json"},
    method="POST"
)

with urllib.request.urlopen(login, timeout=20) as response:
    token = json.loads(response.read().decode())["token"]

print("Авторизация успешна.")

products = request("/products")
product_by_sku = {p["sku"]: p for p in products}

demo_products = [
    ("Молоко пастеризованное", "DEMO-MILK-001"),
    ("Кефир", "DEMO-KEFIR-001"),
    ("Йогурт натуральный", "DEMO-YOGURT-001"),
    ("Сыр твёрдый", "DEMO-CHEESE-001"),
    ("Масло сливочное", "DEMO-BUTTER-001"),
    ("Творог", "DEMO-CURD-001"),
    ("Сметана", "DEMO-SOUR-001"),
    ("Сок яблочный", "DEMO-JUICE-001"),
    ("Вода питьевая", "DEMO-WATER-001"),
    ("Печенье овсяное", "DEMO-COOKIE-001"),
    ("Макароны", "DEMO-PASTA-001"),
    ("Крупа гречневая", "DEMO-BUCKWHEAT-001"),
]

for name, sku in demo_products:
    if sku not in product_by_sku:
        p = request("/products", "POST", {"name": name, "sku": sku})
        product_by_sku[sku] = p
        print("Создан товар:", sku)

warehouses = request("/warehouses")
warehouse = next((w for w in warehouses if w["code"] == "WH-001"), None)

if warehouse is None:
    warehouse = request("/warehouses", "POST", {
        "code": "WH-001",
        "name": "Основной склад",
        "address": "Минск, тестовый адрес"
    })

warehouse_id = warehouse["id"]

locations = request("/storage-locations")
location_by_code = {x["code"]: x for x in locations}

zone_names = ["A", "B", "C", "D"]
for zone in zone_names:
    for row in range(1, 3):
        for cell in range(1, 4):
            code = f"DEMO-{zone}-{row:02d}-{cell:02d}"
            if code not in location_by_code:
                location = request("/storage-locations", "POST", {
                    "warehouseID": warehouse_id,
                    "code": code,
                    "zone": f"Зона {zone}",
                    "details": f"Демонстрационная ячейка {row}-{cell}"
                })
                location_by_code[code] = location
                print("Создана ячейка:", code)

batches = request("/batches")
batch_by_number = {b["batchNumber"]: b for b in batches}
placements = request("/batch-placements")
placed_pairs = {
    (p["batchID"], p["storageLocationID"])
    for p in placements
}
placed_quantity = {}
for p in placements:
    placed_quantity[p["batchID"]] = (
        placed_quantity.get(p["batchID"], 0) + p["quantity"]
    )

now = datetime.now(timezone.utc)
today = now.date()
sku_list = [sku for _, sku in demo_products]
location_codes = sorted(
    code for code in location_by_code if code.startswith("DEMO-")
)

# Разные сроки годности: просроченные, срочные и обычные запасы.
expiry_offsets = [-12, -4, -1, 0, 1, 2, 3, 5, 6, 7, 10, 18,
                  25, 35, 45, 60, 75, 90, 120, 150, 180, 210, 240, 270]

created_batches = 0
created_placements = 0

for i, offset in enumerate(expiry_offsets):
    sku = sku_list[i % len(sku_list)]
    product_id = product_by_sku[sku]["id"]
    batch_number = f"DEMO-BATCH-{i + 1:03d}"

    if batch_number in batch_by_number:
        batch = batch_by_number[batch_number]
    else:
        received = now - timedelta(days=max(1, 30 - offset))
        expiry = datetime.combine(
            today + timedelta(days=offset),
            datetime.min.time(),
            tzinfo=timezone.utc
        )
        # Срок должен быть позже даты поступления.
        if expiry <= received:
            received = expiry - timedelta(days=20)

        batch = request("/batches", "POST", {
            "productID": product_id,
            "batchNumber": batch_number,
            "quantity": 100,
            "receivedAt": received.isoformat().replace("+00:00", "Z"),
            "expiresAt": expiry.isoformat().replace("+00:00", "Z")
        })
        batch_by_number[batch_number] = batch
        created_batches += 1
        print("Создана партия:", batch_number, "срок:", expiry.date())

    batch_id = batch["id"]
    available = batch["quantity"] - placed_quantity.get(batch_id, 0)
    if available <= 0:
        continue

    # Распределяем партии по разным ячейкам; часть партий делим между двумя.
    first_code = location_codes[i % len(location_codes)]
    first_location_id = location_by_code[first_code]["id"]

    if (batch_id, first_location_id) not in placed_pairs:
        qty = min(available, 35 + (i % 4) * 10)
        request("/batch-placements", "POST", {
            "batchID": batch_id,
            "storageLocationID": first_location_id,
            "quantity": qty
        })
        placed_pairs.add((batch_id, first_location_id))
        placed_quantity[batch_id] = placed_quantity.get(batch_id, 0) + qty
        available -= qty
        created_placements += 1
        print("Размещена партия:", batch_number, "в", first_code)

    if available > 0 and i % 3 == 0:
        second_code = location_codes[(i + 5) % len(location_codes)]
        second_location_id = location_by_code[second_code]["id"]
        if (batch_id, second_location_id) not in placed_pairs:
            qty = min(available, 20)
            request("/batch-placements", "POST", {
                "batchID": batch_id,
                "storageLocationID": second_location_id,
                "quantity": qty
            })
            placed_pairs.add((batch_id, second_location_id))
            placed_quantity[batch_id] = placed_quantity.get(batch_id, 0) + qty
            created_placements += 1
            print("Дополнительное размещение:", batch_number, "в", second_code)

print("\nЗаполнение завершено.")
print("Новых партий:", created_batches)
print("Новых размещений:", created_placements)

print("\nПроверка аналитики:")
print(json.dumps(request("/analytics"), ensure_ascii=False, indent=2))

print("\nПроверка FEFO:")
fefo = request("/fefo")
print("Позиций:", fefo["totalPositions"])
print("Количество:", fefo["totalQuantity"])
print("Просроченных:", fefo["expiredPositions"])
print("Истекают за 7 дней:", fefo["expiringWithinSevenDays"])
