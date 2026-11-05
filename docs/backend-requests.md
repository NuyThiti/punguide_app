# งานหลังบ้าน (travel-planner-api) ที่ต้องแก้ก่อนเปิดให้ผู้ใช้ทดลอง

สรุปจากการทดสอบแอป PunGuide (iOS simulator) กับ production API เมื่อ 4 พ.ย. 2026
และอ่านโค้ด `travel-planner-api` ที่ commit `ff40c5a`

| # | เรื่อง | ความสำคัญ |
|---|---|---|
| 1 | โพสต์ที่ไม่มีแผนเชื่อม Remix ไม่ได้ | 🔴 ต้องตัดสินใจ + แก้ |
| 2 | ยังไม่มีระบบรายงาน / บล็อก | 🔴 App Store บังคับ |
| 3 | ตั้ง `SHARE_BASE_URL` / `CORS_ORIGIN` ให้ชี้เว็บใหม่ | 🔴 config |
| 4 | Remix ทั้งทริปไม่ copy ภาพปก | 🟠 |
| 5 | เจ้าของ Remix ทริปตัวเองแล้ว remixCount ขึ้น | 🟠 |
| 6 | ลิงก์แชร์ของโพสต์ไม่มีเนื้อหาโพสต์ | 🟠 |
| 7 | ลบบัญชีไม่ลบผู้ใช้ใน Firebase / เตรียม Sign in with Apple | 🟠 |
| 8 | Response ช้าเป็นบางครั้ง | 🟡 |

---

## 🔴 1. โพสต์ที่ไม่มีแผนเชื่อม Remix ไม่ได้ — ซึ่งคือเกือบทุกโพสต์

**ปัญหา** โพสต์ public บน production มี 27 โพสต์ มีแผนเชื่อม (`linkedTrip`) แค่ **1** โพสต์
`GET /trips/:id` ตอบ `canRemix: false` ให้ทุกโพสต์ที่ไม่มีแผน แม้ตั้ง
`remixEnabled: true` + `remixAudience: everyone` และ `POST …/remix/items/into/…`
ตอบ 422 *"This post has no linked plan to remix"* ผลคือ **ตอนนี้ผู้ใช้ Remix โพสต์ของคนอื่นแทบไม่ได้เลย**
ขณะที่หน้าแอปยังโชว์ไอคอน 🔀 / ยอด Remix บนโพสต์อยู่

**ทำซ้ำ**
1. เข้าสู่ระบบด้วยบัญชีใดก็ได้ที่ไม่ใช่เจ้าของ
2. `GET /trips/2de2f3c1-cf35-460a-a2a2-063df2554bff` (“อั๋วจาไปเยาวราช”, 5 สถานที่)
3. ได้ `canRemix: false`, `remixEnabled: true`, `remixAudience: "everyone"`, `linkedTrip: null`

**โค้ด** `src/manager/trips/trips-manager.service.ts:621` (`!isPostType(trip.type) || hasLinkedPlan`),
`src/model/trips/trips.service.ts` ~บรรทัด 1965 (422)

**ต้องตัดสินใจร่วมกับทีมแอป** (เลือกอย่างใดอย่างหนึ่ง)
- **A.** ให้ remix-items-into รับสถานที่จาก `contents[].location` ของโพสต์ได้โดยตรง (ไม่ต้องมีแผน) แล้ว `canRemix` ตามสิทธิ์ปกติ
- **B.** ตอนเผยแพร่โพสต์ ให้สร้าง/เชื่อมแผนจากสถานที่ในโพสต์อัตโนมัติ
- **C.** คงพฤติกรรมเดิม — แอปจะซ่อน 🔀 บนโพสต์ที่ Remix ไม่ได้ (ไม่ต้องแก้หลังบ้าน)

---

## 🔴 2. ยังไม่มีระบบรายงานเนื้อหา / บล็อกผู้ใช้

**ปัญหา** แอปมีเนื้อหาที่ผู้ใช้สร้าง (โพสต์, คลิป Puntok, แผน) แต่ API ไม่มี endpoint รายงานหรือบล็อกเลย
(ค้นใน `src/api` ไม่พบ `report` / `block`) — App Store Review Guideline 1.2 บังคับสำหรับแอปที่มี UGC
และมักโดนตีกลับตอนส่ง External TestFlight / App Store

**เสนอ**
- `POST /reports` — `{ targetType: "trip" | "user" | "media", targetId, reason, note? }` เก็บไว้ให้ทีมตรวจ
- `POST /users/:userId/block`, `DELETE /users/:userId/block`, `GET /users/me/blocks`
- ฟีด (`GET /trips`), ค้นหา และ Puntok ต้องกรองเนื้อหาของคนที่ผู้ชมบล็อกออก
- (ถ้าทำได้) ซ่อนเนื้อหาที่ถูกรายงานเกิน N ครั้งชั่วคราวจนกว่าจะตรวจ

---

## 🔴 3. ตั้ง `SHARE_BASE_URL` และ `CORS_ORIGIN` ให้ชี้เว็บที่ deploy ใหม่

**ปัญหา** `shareUrl` ที่ `POST /trips/:id/share` คืนมา สร้างจาก `SHARE_BASE_URL`
(ถ้าว่างจะใช้ origin แรกของ `CORS_ORIGIN`) — `src/config/configuration.ts:210`
เว็บย้ายมาอยู่ project ใหม่ `paigun-punguide-planer.vercel.app` แล้ว (project เดิม
`pluno-travel-planer.vercel.app` อยู่ในบัญชีของคนที่ลาออก)
ถ้าค่าบน Cloud Run ยังชี้โดเมนเดิม ลิงก์แชร์จะพังทันทีที่ project เดิมถูกลบ

**ต้องทำ**
- ตั้ง `SHARE_BASE_URL=https://<โดเมนเว็บใหม่>` บน production (ผลลัพธ์: `https://<โดเมน>/shared-trips/<token>`)
- เพิ่มโดเมนใหม่ใน `CORS_ORIGIN`
- ระยะยาว: ใช้โดเมนของบริษัทเอง แล้วอัปเดตทั้งสองค่าอีกครั้ง
- หมายเหตุ: `pluno-service` ไม่มี auto-deploy — ต้อง deploy มือหลังแก้

---

## 🟠 4. Remix ทั้งทริปไม่ copy ภาพปก

**ปัญหา** `POST /trips/:id/remix` สร้างทริปใหม่พร้อมวัน/สถานที่ แต่ไม่ได้ copy `coverMediaId`
ทริปที่ remix มาจึงขึ้นภาพ fallback แทนภาพปกต้นฉบับ

**ทำซ้ำ**
1. Remix “น่าน 3 วัน 2 คืน” (`6b9af9d4-fc53-40b3-8066-c406e16f6089`, มีภาพปกหมู่บ้านน่าน)
2. ทริปใหม่ (`2470d6df…`, ลบแล้วหลังทดสอบ) ขึ้นภาพหุบเขาสีแดง (ภาพ default)

**เสนอ** ตอน remix ให้ใช้ภาพปกเดิม (อ้าง media เดิม หรือ copy media row ให้เจ้าของใหม่)
ถ้าตั้งใจไม่ copy เพราะเรื่องสิทธิ์รูป ให้ตอบ `coverImage: null` ชัด ๆ แล้วแอปจะแสดง placeholder ของตัวเอง

---

## 🟠 5. เจ้าของ Remix ทริปตัวเองแล้ว `remixCount` ขึ้น

**ปัญหา** `creditRemix` (`src/model/trips/trips.service.ts` ~บรรทัด 1975) เพิ่ม `remixCount` ทุกครั้ง
รวมถึงตอนที่เจ้าของทำสำเนาทริปของตัวเอง ทำให้ยอด “คนที่เอาไปใช้” เฟ้อ

**ทำซ้ำ** เจ้าของ remix “น่าน 3 วัน 2 คืน” ของตัวเอง → `remixCount` จาก 0 เป็น 1

**เสนอ** ข้ามการ credit เมื่อ `requestedTrip.ownerId === viewerId`
(และพิจารณาว่าจะนับซ้ำไหมเมื่อคนเดิม remix ทริปเดิมหลายครั้ง)

---

## 🟠 6. ลิงก์แชร์ของโพสต์ไม่มีเนื้อหาโพสต์

**ปัญหา** `GET /shared-trips/:token` (`src/api/share/dto/public-shared-trip.response.dto.ts`)
ส่งแค่ `title, destination, tags, coverImage, days, likeCount, remixCount, updatedAt`
ไม่มี `contents` (ข้อความ + รูปแต่ละส่วนของโพสต์) — แชร์โพสต์แล้วคนรับเห็นแค่หัวข้อกับภาพปก

**เสนอ** เพิ่ม `type` และ `contents[]` (title, content, media ที่เป็น public URL, location name)
ในรูปแบบ allow-list เดียวกับ field อื่น ๆ (ไม่มี id / ไม่มีเงิน)

---

## 🟠 7. ลบบัญชี / เตรียม Sign in with Apple

**สถานะ** `DELETE /users/me` มีแล้ว และบัญชีที่เข้าด้วย Google (ไม่มีรหัสผ่าน) ลบได้โดยไม่ต้องยืนยันรหัส ✅

**ที่ยังขาด**
- ไม่ได้ลบผู้ใช้ใน **Firebase Auth** (`firebase-admin` `deleteUser(uid)`) — คนที่ลบบัญชีแล้วยังมี identity ค้างใน Firebase
- แอปกำลังจะเพิ่ม **Sign in with Apple** (App Store บังคับเมื่อมี Google login):
  - ยืนยันว่า `POST /auth/firebase` รับ token ที่ `sign_in_provider = apple.com` ได้
  - อีเมลอาจเป็น `@privaterelay.appleid.com` หรือไม่มีเลย — โค้ดปัจจุบันรองรับอีเมลว่างแล้ว (`auth-manager.service.ts:120–157`) แต่ควรมีเทสต์
  - Apple ส่งชื่อมาแค่ครั้งแรก → ให้ `POST /auth/firebase` รับ `name` จาก client (optional) ไว้ตั้งชื่อตอนสร้างบัญชี
  - ตอนลบบัญชีของผู้ใช้ Apple ต้อง **revoke Apple token** (Apple บังคับ) — ต้องรับ `authorizationCode` จากแอปแล้วเรียก Apple `/auth/revoke`

---

## 🟡 8. Response ช้าเป็นบางครั้ง

| Endpoint | เวลาที่เจอในแอป | วัดซ้ำ (ไม่ login) |
|---|---|---|
| `GET /trips/2de2f3c1…` | 5,987 ms (ผ่าน backend local) | 0.29–0.39 s |
| `GET /trips/6b9af9d4…/media?limit=200` (เจ้าของ, login) | 4,446 ms (prod) | 0.17–0.20 s |

ส่วนใหญ่เร็ว น่าจะเป็น cold start ของ Cloud Run หรือการ sign URL ของรูปตอน login
**เสนอ** ตั้ง Cloud Run `min-instances=1` และดู log latency ของ `/media` ตอนเป็นเจ้าของ

---

## ไม่ต้องแก้หลังบ้าน (ฝั่งแอปทำเอง) — แจ้งไว้กันสับสน

- **สถานที่ที่ Remix ลงทริป (staging shelf) ไม่แสดงในแอป** — API ส่ง `stagedItems` และมี
  `PATCH /items/:id/assign` ครบแล้ว แอปยังไม่ได้ทำ UI
- **Remix ทั้งทริปเคยไม่เรียก API** — แก้ในแอปแล้ว (เรียก `POST /trips/:id/remix` + Idempotency-Key)
- **ปุ่ม “ติดตาม”** — API มีแล้ว (`/users/:userId/follow`, `/follow-summary`) แอปยังไม่ได้ต่อ
- **Remix ลงทริปใหม่ไม่ได้ / ชื่อทริปซ้ำกันในตัวเลือก / ไม่มีปุ่มเปิดทริปหลัง Remix** — UX ฝั่งแอป

## ข้อมูลทดสอบที่ค้างอยู่บน production

- ทริป “น่าน 3 วัน 2 คืน” (`6b9af9d4…`) มี 2 สถานที่ค้างบน shelf (Dragon Bridge, My Khe Beach)
  — ลบได้ด้วย `DELETE /items/69944e94-afb5-4dcf-a444-65e6205383e4` และ `DELETE /items/c5857d71-451c-41ef-bbc5-8a36164d55b6`
- `remixCount` ของ “ซินจ่าว ดานัง-ฮอยอัน” (`cb3e0ce5…`) +1 และของ “น่าน” +1 จากการทดสอบ — ถ้าต้องการให้ตรง ปรับใน DB ได้
