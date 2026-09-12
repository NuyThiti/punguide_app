# สร้างโพสต์จากรูปทริป — contract Plan trip / Content post

ปรับตามเอกสาร API ที่ส่งให้ frontend รอบล่าสุด โดยไม่แก้ backend และคง Create Post editor/สี #FF8569 เดิม

## Model และ API

- `TripType.planTrip` / `TripType.content` แยกจาก `planMode`; List/Detail ที่ไม่มี type fallback เป็น plan_trip, withSaved/copyWith เก็บ type เดิม
- POST /trips ส่ง type และรองรับ Idempotency-Key; manual plan ส่ง plan_trip, Create Post ส่ง content; POST /trips/create ส่ง type ผ่าน TripDraft
- PATCH ละ type/contents เมื่อไม่ได้แก้ คงความต่างระหว่าง omission กับ contents: []
- TripContent เป็น response model; TripContentRequest เป็น allowlist serializer สำหรับ content, title, mediaIds, location, photoMetadata หรือ legacy URL-only โดยไม่ส่ง images/local path/storageKey กลับ
- ตรวจสูงสุด 100 ส่วน, 20 รูปต่อส่วน, รวม 200 references; UUID ไม่ซ้ำภายในส่วน; metadata ต้องอ้างรูปในส่วนเดียวกัน; ไม่ผสม mediaIds/imageUrls หรือ location/mapId

## Composer และการเผยแพร่

- เลือกหลายรูป จัดกลุ่มตาม EXIF แยกจาก widget และต่อท้ายงานเขียนเดิม ไม่เดาสถานที่/ข้อความและไม่ลบรูปซ้ำ
- ลากรูปเรียงหรือย้ายข้ามส่วน เพิ่ม/ลบส่วน สลับส่วน และเลือกปกด้วยตนเอง การลบปกไม่เลือกภาพอื่นแทนโดยอัตโนมัติ
- ชื่อ/จุดหมายระดับ Trip ยังจำเป็น หากข้อมูลที่ผู้ใช้เขียน/เลือกยังไม่ครบ เปิด dialog ให้กรอกครั้งเดียว พิมพ์จุดหมายเองได้ ไม่ต้องมีหมุด และไม่เติมข้อความสมมติ
- ส่วนที่มีเพียงรูปส่ง content: "" ได้โดยไม่มีหัวข้อ/สถานที่ เลือกชื่อสถานที่จากผลค้นหาหรือกด “ใช้ชื่อที่พิมพ์เอง” เป็น confirmed ได้โดยไม่ต้องมี mapId
- location ที่โหลดมาเป็น suggested แสดง “สถานที่ที่แนะนำ” และรอการยืนยัน/แก้ไข; การลบส่ง status: none; legacy mapId แสดงใน editor ว่ายังไม่ยืนยัน
- Upload ใหม่ใช้ mediaId ของ Trip นี้ตามลำดับ UI เก็บ mapping แยกจากลำดับ และเก็บรายการสำเร็จเมื่อรายการอื่นล้มเหลว
- ใช้ UUID เดิมและ creation payload เดิมเมื่อ retry สร้างร่าง แล้ว PATCH ค่าล่าสุดบน ID เดิมเมื่อ publish
- ถ้า upload ไม่มี response หรือ 5xx ถือว่าไม่ทราบผล: retry เปิด gallery ให้เทียบกับรูปต้นฉบับ ผู้ใช้เลือกรูปที่มีแล้ว หรือยืนยันว่าไม่พบก่อนส่งใหม่ ไม่มีการ reupload อัตโนมัติ
- Final PATCH ส่ง contents ล่าสุดและ visibility ด้วยกัน ไม่มี network autosave ที่อาจเขียนทับ เมื่อจะลบไฟล์หน้าปกที่เอาออกจากเนื้อหา ส่ง PATCH เอา reference ออกก่อน DELETE และค่อย final publish
- รูปอื่นที่นำออกจาก contents ยังคงอยู่ใน gallery ไม่ลบไฟล์อัตโนมัติ; ปกที่เป็น gallery-only และไม่ได้ถูกเอาออกจะคงเดิม

## การอ่านและแก้โพสต์

- Detail ใช้ type เลือก UI; content ไม่แสดง itinerary/budget/remix ส่วน plan_trip ยังคง flow เดิมและแสดง contents ได้
- แสดง resolved images ตามลำดับในแต่ละส่วน ไม่ใช้ gallery จัดเรื่องราว; unavailable แสดง placeholder ณ ตำแหน่งเดิม
- Public detail วาดหมุดเฉพาะ confirmed ไม่แสดงข้อมูล suggested หรือยกระดับ legacy mapId เป็น confirmed
- เจ้าของเปิด “แก้ไขโพสต์” จาก Detail ได้ โหลดข้อความ/ลำดับ/mediaId/metadata กลับเข้า editor เดิม ไม่อัปโหลดไฟล์ที่มี mediaId แล้วซ้ำ unavailable ต้องเอา reference ออกหรือเลือกใหม่ก่อน publish
- Legacy URL-only ยังคงอ่านและบันทึก URL เดิมได้ รูปใหม่ต้องอยู่คนละส่วน ไม่แปลง URL เป็น mediaId สมมติ
- ร่างแยกตาม post ID ใน Riverpod รวม create key/upload mapping และกลับมาแก้ต่อได้ใน app session เดิม

## Metadata และไฟล์

อ่าน DateTimeOriginal เท่านั้น ไม่ใช้ filesystem modified time/Media.createdAt เป็นเวลาถ่าย เกณฑ์จัดกลุ่ม: ข้ามวัน, ห่างเกิน 3 ชั่วโมง หรือไกลกว่า 2 กม. รูปที่ไม่มีเวลาหรือ GPS เป็นจุดยึดลำดับที่เลือก เรียงเวลาเฉพาะช่วงต่อเนื่องที่ข้อมูลครบ

ส่ง takenAt เฉพาะเมื่อมี timezone จาก EXIF OffsetTimeOriginal หรือ owner response; ไม่ทราบ timezone ให้ omit แม้ยังใช้เวลาท้องถิ่นช่วยจัดกลุ่มได้ พิกัดส่งเฉพาะเมื่อครบคู่และถูกต้อง ไม่สร้างหมุดอัตโนมัติ

ก่อน upload ตรวจ 15 MiB / 40 ล้าน pixels ส่ง JPEG/PNG/WebP พร้อม MIME ของ multipart โดย HTTP client กำหนด boundary รูปอื่นรวม HEIC ใช้ platform image codec แปลงเป็น PNG เมื่อรองรับ หากแปลงไม่ได้หรือเกินขนาด จะแจ้งให้เลือกไฟล์ที่รองรับและเก็บรูปเดิมในร่าง ไม่ตัดทิ้ง

## ข้อจำกัดและ deployment

- Backend ต้อง deploy contract นี้และรัน migrations AddTripContents, AddTripType และ idempotency ตามเอกสารก่อนใช้งานจริง งานนี้ไม่ได้รัน migration หรือเรียก mutation กับ backend จริง
- ตาม contract การ PATCH visibility: public คือ publish บน ID เดิม ไม่ต้องเพิ่ม status หรือสร้าง Trip ใหม่
- ยังต้องทดสอบบนเครื่องจริงสำหรับ limited photo permission, HEIC codec และ timeout กับ server จริง
- ร่างเป็น app-session memory ไม่ใช่การบันทึกถาวรหลัง force quit/process death; ไม่ได้เพิ่ม Android lost-data recovery หรือคัดลอก picker cache ไป storage ถาวร
- Gallery reconciliation ให้ผู้ใช้เทียบภาพ ไม่จับคู่จากเวลาอัปโหลดหรือชื่อไฟล์โดยการเดา ไม่มี conflict merge หลาย editor
- Private Trip ไม่ใช่ access control ของ URL รูป ตามข้อจำกัด public storage ใน contract

## การตรวจสอบ

Tests ครอบคลุม type/default/copy, omission/clear, request allowlist, legacy, metadata validation, grouping, photo-only publish, owner edit/reorder, suggested confirmation, unavailable, create idempotency, partial/uncertain upload reconciliation, cover deletion ordering และ editor layout

การรันชุดทั้งหมดพบ 8 failures ใน paigun_filter, widget, view_plan, saved_trips_screen_layout และ home_screen_layout; ตรวจซ้ำด้วยโค้ด HEAD เดิมใน /tmp แล้วพบ 8 failures เดียวกัน ผลสุดท้ายทั้งโปรเจกต์: 246 ผ่าน / 8 failures เดิม; ทุกเคสของ API contract และ Create Post ผ่าน Analyzer ของไฟล์ที่เกี่ยวข้องไม่มี error และเหลือ warning เดิมหนึ่งรายการ (_CreatorRow ไม่ถูกใช้)
