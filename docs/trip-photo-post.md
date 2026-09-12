# สร้างโพสต์จากรูปทริป

## Frontend ที่เพิ่ม

- ใช้ CreatePostScreen, PostBlock, PostDraft, Riverpod และ image_picker เดิม เพิ่มเฉพาะ exif 3.3.0 (sprintf เป็น transitive dependency)
- ทางเข้า “สร้างจากรูปทริป” ก่อน editor ใช้สี AppColors.createTop (#FF8569) โดยไม่เปลี่ยนธีมทั้งแอป
- เลือกหลายรูปจาก system picker โดยไม่ resize/compress ก่อนอ่าน metadata แสดง loading และยกเลิกได้ กลับมาตรวจใน editor เดิม
- รูปที่จัดแล้วต่อท้ายเนื้อหาที่มีอยู่ ยกเว้นส่วนเริ่มต้นที่ว่างเปล่า ไม่ลบรูปซ้ำ ไม่สร้างข้อความ หัวข้อ หรือชื่อสถานที่
- ลากรูปไปวางก่อนรูปอื่นหรือท้ายส่วนได้ และมีปุ่ม “ย้ายรูป” เลือกส่วนปลายทางสำหรับส่วนที่อยู่นอกจอ เพิ่ม/ลบรูป เพิ่ม/ลบส่วน (คงอย่างน้อยหนึ่งส่วน) สลับส่วนด้วยขึ้น/ลง และเลือกหน้าปกได้
- ชื่อสถานที่มาจากการเลือกยืนยันใน place picker เดิมเท่านั้น ไม่มี reverse geocoding หรือชื่อสถานที่แนะนำอัตโนมัติในรอบนี้ GPS ใช้จัดกลุ่มเท่านั้น จึงไม่มีชื่อที่ยังไม่ยืนยันถูกส่งเป็น mapId
- ร่างและข้อมูล retry upload เก็บใน Riverpod เมื่อปิดหน้า เปิดกลับมาใน app session เดิมได้ ผล import ที่กลับมาหลังยกเลิก/ออกหน้าถูกละทิ้ง

## เกณฑ์จัดกลุ่ม

TripPhotoGrouper แยกจาก widget: วันต่างกัน, เวลาห่างเกิน 3 ชั่วโมง หรือพิกัดห่างเกิน 2 กม. จะขึ้นส่วนใหม่ ทุกส่วนไม่เกิน 20 รูป และ editor ไม่เกิน 100 ส่วน ถ้า import เกินขีดจำกัด ยกเลิกทั้งชุดพร้อมแจ้ง ไม่ตัดรูปเงียบ ๆ

อ่าน EXIF DateTimeOriginal และ GPS ที่ถูกต้องเท่านั้น ไม่อ่าน filesystem modified time หรือ Image DateTime มาเป็นเวลาถ่าย การอ่าน/parse อยู่ใน compute แยก isolate บน mobile อ่านทีละไฟล์

เพื่อรักษาลำดับที่เลือกเมื่อข้อมูลขาด: รูปที่ไม่มีเวลาหรือ GPS เป็นจุดยึดลำดับ เรียงเวลาเฉพาะช่วงต่อเนื่องที่มีข้อมูลทั้งสองอย่าง เวลาที่มีอยู่ยังใช้พิจารณาแบ่งวัน/ช่วงได้ ไฟล์ที่อ่าน metadata ไม่ได้ยังอยู่ในร่าง ชนิดไฟล์/metadata ที่ parser ไม่รองรับจะใช้ fallback เดียวกัน

## Payload และข้อจำกัด backend

Flow เดิมคือ POST /trips → upload media → PUT /trips/:id/cover → PATCH /trips/:id (contents, visibility) และ retry บน draft ID เดิม ไม่เพิ่ม endpoint และไม่แก้ backend

TripContent.toJson รองรับ title/content เป็นสตริงว่าง, imageUrls ไม่เกิน 20 และละ mapId ได้ ส่วน API client createDraft ยัง require title และ destination; ใน repository มี test ของ server validation `title should not be empty` แต่ไม่มี backend schema ที่ยืนยันการรับโพสต์รูปอย่างเดียว

จึงเอา fallback “โพสต์ใหม่” และ “ไม่ระบุจุดหมาย” ออก ไม่สร้างข้อมูลเพื่อผ่าน validation ปุ่ม “ปันไกด์” รับร่างที่มีรูปได้ แต่ถ้าหาชื่อจากข้อความ/หัวข้อ/ทริป และจุดหมายจากสถานที่ที่ยืนยัน/ทริปไม่ได้ จะแจ้งข้อจำกัดก่อนเรียก API ร่างยังแก้ไขได้

Backend ต้องยืนยัน/รองรับการสร้าง post draft โดยไม่บังคับ trip title/destination และยอมรับ section ที่มีเฉพาะรูป หากใช้ endpoint ใหม่ต้องเพิ่ม API adapter ภายหลัง Flow เดิมนี้บันทึก contents/visibility โดยไม่มี publish-status endpoint แยก จึงยังไม่ได้ยืนยันว่าฝั่ง server เปลี่ยน status จาก draft เป็น published จริง

## ขอบเขตการตรวจสอบ

Unit/widget tests ครอบคลุม EXIF fixture, grouping, ข้อมูลหาย/อ่านไม่ได้, รูปซ้ำ, ขีดจำกัดรูปต่อส่วน, append, move/reorder, cancel/late result, permission error, ปิดแล้วเปิดร่าง, photo-only API blocker, cover/upload/retry และ phone layout

ยังต้องทดสอบบนเครื่องจริงสำหรับ iOS limited-library access, Android photo picker และไฟล์ HEIC ของอุปกรณ์จริง ไม่ขอ full-library permission เพิ่มเอง แต่ใช้พฤติกรรม system picker ของ dependency เดิม ร่างเก็บใน memory ของ app session ไม่ใช่ persistent draft หลัง force quit/process death; ยังไม่ได้เพิ่ม Android lost-data recovery หรือสำเนารูปจาก picker cache ถาวร
