# ขอหลังบ้าน — เพิ่ม `type: "puntok"` สำหรับโพสต์ Puntok

ตอนนี้โพสต์ที่สร้างจากหน้า **New Puntok** (Figma: PaiGun PunGuide › Puntok) ถูกเก็บเป็น
`"type": "content"` เหมือนโพสต์ PunGuide ทั่วไป เพราะ API ยังไม่มี type ของ Puntok
แอปฝั่ง client เตรียมไว้แล้ว รอแค่หลังบ้านรองรับ

ตรวจล่าสุด 2026-10-21 กับ `travel-planner-api-git-909858882015.asia-northeast3.run.app`
· Linear: TEC-1533

## ปัญหาตอนนี้

```bash
curl "$BASE_URL/trips?type=puntok"
# 400 {"message":["type must be one of the following values: plan_trip, content"],
#      "error":"Bad Request","statusCode":400}
```

- `POST /trips/posts` ไม่ได้ส่ง `type` → server ใส่ `content` ให้เอง โพสต์ Puntok จึงปนกับโพสต์ PunGuide
- feed Puntok ต้องดึง `GET /trips?type=content` แล้ว **กรองฝั่งแอปเอง** ว่าการ์ดไหนมีปกเป็นวิดีโอ
  ดูจากนามสกุลไฟล์ใน `coverImage.urls.original` (`.mp4`/`.mov`) เพราะ list ยังไม่ส่ง `mediaType`
  วิธีนี้เปราะ และกินโควตา `limit` ไปกับโพสต์รูปที่ต้องทิ้ง

## สิ่งที่ขอ

### 1. เพิ่ม `puntok` ใน enum ของ `type`

| | ตอนนี้ | ที่ขอ |
| --- | --- | --- |
| `trips.type` (DB enum) | `plan_trip`, `content` | `plan_trip`, `content`, **`puntok`** |

ต้องมี migration เพิ่มค่าใน enum ของคอลัมน์ `type`

### 2. `POST /trips/posts` และ `PUT /trips/posts/:id` รับ `type`

```bash
curl -X POST "$BASE_URL/trips/posts" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -H "Idempotency-Key: <uuid>" \
  -d '{
    "type": "puntok",
    "action": "share",
    "visibility": "followers",
    "title": "เดินพระนคร 1 วัน",
    "description": "เดินพระนคร 1 วัน\nกินข้าวต้มเช้า",
    "coverMediaId": "<video mediaId>",
    "contents": [{ "content": "…", "mediaIds": ["<video1>", "<video2>"], "location": { "status": "none" } }],
    "remixEnabled": true,
    "remixAudience": "link"
  }'
```

- ค่าที่รับ: `content` | `puntok`
- **ไม่ส่ง `type` = `content`** เหมือนเดิม โพสต์ PunGuide ที่มีอยู่ไม่ต้องแก้อะไร
- แอปส่ง `type` **ทุกครั้งที่บันทึก** (POST ครั้งแรก + PUT ทุกครั้งหลังจากนั้น) ดังนั้น PUT ต้องรับค่าเดิมซ้ำได้
- ข้อเสนอ: ถ้า PUT ส่ง `type` คนละค่ากับที่โพสต์เป็นอยู่ ให้ตอบ `400` (ไม่ให้เปลี่ยนประเภทโพสต์ทีหลัง)
- `action: draft` / `share`, `draftVisibility`, `publishedAt` ใช้กติกาเดียวกับ `content` ทุกอย่าง

### 3. `GET /trips` กรองด้วย `type=puntok` ได้

| Method | Path | ที่ขอ |
| --- | --- | --- |
| `GET` | `/trips?type=puntok&sort=popular` | แท็บ **Top Punguide** |
| `GET` | `/trips?type=puntok&sort=recent` | แท็บ **For you** |
| `GET` | `/trips/mine`, `/trips/saved` | ส่ง `"type": "puntok"` กลับมาในการ์ด |
| `GET` | `/trips/:id` | ส่ง `"type": "puntok"` กลับมา |

- `type=content` ควรคืน **เฉพาะ** `content` (ไม่รวม `puntok`) เพื่อให้แท็บ PunGuide/ไปกัน ยังเป็นโพสต์รูปเหมือนเดิม
- คำถาม: ถ้าทำได้ ขอให้ `type` รับหลายค่า เช่น `type=content,puntok` สำหรับหน้าที่อยากรวมทั้งสองแบบ
  (ถ้ายังไม่ทำ แอปไม่ถูกบล็อก)

### 4. กติกาอื่นเหมือน `content` ทั้งหมด

`puntok` คือโพสต์ประเภทหนึ่ง ใช้ทุกอย่างร่วมกับ `content`:

- การมองเห็น `public` / `followers` / `private` และสิทธิ์ดูเหมือนเดิม
- `remixEnabled`, `remixAudience`, `canRemix`
- `linkedTripId` → `linkedTrip` (รวมใน list ตาม linked-plan update)
- `contents[]`, `coverMediaId`, `travelStyles`, `customStyles`, `destinationPlace`
- like / save / ลบ / ลิงก์แชร์
- AI chat ค้นหาโพสต์ `public` — รวม `puntok` ด้วยหรือไม่ แล้วแต่หลังบ้าน (แจ้งแอปด้วย)

### 5. (ข้อเสนอ) validation ของ `puntok`

- ตอน `action: share` ต้องมีวิดีโออย่างน้อย 1 ไฟล์ใน `contents[].mediaIds` ถ้าไม่มีตอบ `400`
- `coverMediaId` ควรเป็นวิดีโอ หรือรูปปกของวิดีโอในโพสต์เดียวกัน

### 6. ย้ายโพสต์ Puntok ที่สร้างไปแล้ว

โพสต์ที่สร้างจากแอปก่อนหน้านี้เป็น `content` อยู่ ขอ migrate เป็น `puntok`:
เงื่อนไขแนะนำคือ `type = 'content'` และ `coverImage` เป็นวิดีโอ (`media_type = 'video'`)

ที่รู้แน่ ๆ: `84b883f1-b1ac-4b41-8d8a-c651967117b4` (สร้าง 2026-10-20, ปกเป็น `.mov`)

## ฝั่งแอปพร้อมแล้ว

- `TripType.puntok` อ่านค่า `"puntok"` ได้แล้ว และแสดงเหมือนโพสต์ (`content`) ทุกหน้า
  (detail, ทริปฉัน, การ์ด Home, AI chat)
- `savePost(type:)` ส่ง `type` ได้แล้ว
- สลับใช้งานจริงแก้บรรทัดเดียว: `puntokTripType` ใน
  `lib/features/puntok/domain/models/puntok_post.dart` จาก `TripType.content` → `TripType.puntok`
  แล้ว feed จะ query `type=puntok` และหน้า New Puntok จะส่ง `type: "puntok"`
- **ห้ามสลับก่อนหลังบ้าน deploy** ไม่งั้น feed Puntok ได้ 400 ทั้งหน้า

## เรื่องอื่นที่เจอระหว่างต่อ Puntok (ไม่บล็อกข้อนี้ แต่ฝากดู)

| # | เรื่อง | ที่เห็นบน production (2026-10-20) |
| --- | --- | --- |
| A | `coverImage` ใน list (`GET /trips`) ไม่มี `mediaType` | แอปต้องเดาจากนามสกุลไฟล์ |
| B | วิดีโอไม่มีรูปปก | `urls.large` / `urls.thumbnail` เป็นไฟล์ `.mov` ตัวเดียวกับ `original` แทนที่จะเป็น WebP จากเฟรมแรก (ffmpeg?) |
| C | `linkedTrip` ยังไม่มาใน list | การ์ด "แผนทริป" บน feed ยังไม่ขึ้น |
| D | แท็บ **Following** ไม่มี API | ไม่มี endpoint ติดตาม/เลิกติดตาม และไม่มี filter "โพสต์ของคนที่ฉันติดตาม" |
| E | list ไม่มีจำนวนคอมเมนต์ / แชร์ / บันทึก | ปุ่มด้านข้าง feed ไม่มีตัวเลข |

## เช็กหลัง deploy

```bash
# 1. filter ได้ (ไม่ใช่ 400)
curl -s -o /dev/null -w '%{http_code}\n' "$BASE_URL/trips?type=puntok"   # → 200

# 2. สร้างแล้วได้ type puntok กลับมา
curl -s -X POST "$BASE_URL/trips/posts" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -H "Idempotency-Key: $(uuidgen)" \
  -d '{"type":"puntok","action":"draft","visibility":"private","title":"test"}' | jq .type
# → "puntok"

# 3. ไม่ส่ง type ยังเป็น content
curl -s -X POST "$BASE_URL/trips/posts" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -H "Idempotency-Key: $(uuidgen)" \
  -d '{"action":"draft","visibility":"private","title":"test"}' | jq .type
# → "content"
```
