# ร่างโพสต์จากรูป — contract ฝั่ง client

ต่อจาก [trip-photo-post.md](./trip-photo-post.md) เพิ่มเส้น `POST /trips/:tripId/contents/generate`
ที่อ่านรูปแล้วคืนร่างให้ตรวจ ไม่เขียน DB ใด ๆ ปุ่ม "Creates post from Photos" บนหัว composer เป็นทางเข้าเดียว

## API

- `trips.generateContents(tripId, photos, language, notes, locationName, idempotencyKey)` ตรวจก่อนยิง: 1–20 รูป, mediaId ไม่ซ้ำ, `takenAt` ต้องมี timezone, พิกัดมาคู่, notes ≤ 500, locationName ≤ 200
- `GeneratedPostDraft` อ่าน `title`, `contents` (ใช้ `TripContent` ตัวเดิมที่ PATCH รับ), `locationOptions`, `warnings`
- `locationOptions` เป็นข้อมูลของหน้าตรวจเท่านั้น เก็บใน state ของ composer ไม่เคยถูก serialize กลับ เพราะ PATCH ปฏิเสธ field ที่ไม่รู้จัก

## ลำดับที่ปุ่มทำ

- สร้าง draft trip (ใช้ `_createKey` ตัวเดียวกับ publish จึงไม่เกิดทริปที่สอง) → อัปโหลดทีละรูป → อ่าน EXIF ในแอป → generate
- เพราะ endpoint ต้องมี trip และ mediaId ก่อน การกดร่างแล้วออกจึงทิ้ง draft trip แบบ private ไว้ ไม่ใช่ผลข้างเคียงที่เลี่ยงได้
- ชื่อ/จุดหมายตอนสร้าง draft เป็นค่าชั่วคราว (`ร่างจากรูป` และพิกัดของรูปแรก) ไม่เปิด dialog ขัดจังหวะ เพราะ publish ส่งค่าจริงทับอยู่แล้ว
- upload ที่สำเร็จถูกเก็บใน `_uploaded` publish จึงไม่ส่งไฟล์เดิมซ้ำ; 5xx/ไม่มี response ยังเข้าเส้น uncertain เดิม
- Idempotency-Key ใหม่ทุกครั้งที่กด เพราะ key เดิมคืนร่างเดิม ซึ่งผิดทันทีที่ผู้ใช้เลือกรูปชุดใหม่

## กติกาที่ห้ามหลุด

- **ทุก location ที่ได้มาเป็น `suggested` เท่านั้น** มีแต่การกดของคนที่เปลี่ยนเป็น `confirmed` — ชื่อที่ AI เดาผิดจึงไม่มีทางกลายเป็นข้อมูลสาธารณะโดยไม่มีใครดู
- `locationName` ส่งได้เฉพาะสถานที่ที่ผู้ใช้ปักเอง (`item.place` หรือ location ที่ `confirmed` อยู่แล้ว) สถานที่ที่ผู้ช่วยแนะนำไม่นับ เพราะคำที่เดาผิดออกสู่สาธารณะทันทีที่กดแชร์ ส่วนหมุดที่เดาผิดยังไม่ออก
- `notes` ส่งหัวข้อที่ผู้ใช้พิมพ์ เป็นบริบท ไม่ใช่คำสั่ง และเป็นสิ่งเดียวที่ทำให้ผู้ช่วยใช้ "เรา"
- `warnings` ขึ้นการ์ดค้างไว้จนกด ปิด ไม่ใช้ snackbar เพราะข้อความถัดไปจะกลบทันที

## ร่างที่ได้

- 1 การ์ดต่อ 1 รูป ตามลำดับที่ส่ง ส่วนที่ `content: ""` (โมเดลข้ามหรือจับรวม) ยังได้การ์ดของตัวเองไว้ให้เติมคำ ไม่ยุบรวมกัน
- รูปเกิน 20 ต่อครั้งได้การ์ดของตัวเองต่อท้ายพร้อม warning โพสต์ยังเก็บได้ 200 รูปตามเดิม
- `locationOptions` ของจุดไหน ขึ้นนำในชีต Add Location ของจุดนั้น กดแล้วเขียนเป็น `confirmed` พร้อม `placeId`/พิกัดที่แนบมา
- 503 / 429 / เน็ตล่ม → กลับไปใช้ `TripPhotoGrouper` ในเครื่องเหมือนเดิม และเหตุผลขึ้นบนการ์ด warning
