import 'package:flutter/material.dart';

class PostInfoDialog extends StatefulWidget {
  const PostInfoDialog(
      {super.key, required this.title, required this.destination});
  final String title, destination;
  @override
  State<PostInfoDialog> createState() => _PostInfoDialogState();
}

class _PostInfoDialogState extends State<PostInfoDialog> {
  late final _title = TextEditingController(text: widget.title);
  late final _destination = TextEditingController(text: widget.destination);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('ชื่อโพสต์และจุดหมาย'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'ระบุครั้งเดียวสำหรับโพสต์นี้ ส่วนเนื้อหาไม่จำเป็นต้องมีหัวข้อหรือสถานที่'),
                  TextFormField(
                      controller: _title,
                      maxLength: 200,
                      decoration: const InputDecoration(labelText: 'ชื่อโพสต์'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'กรุณาระบุชื่อโพสต์'
                          : null),
                  TextFormField(
                      controller: _destination,
                      maxLength: 200,
                      decoration: const InputDecoration(
                          labelText: 'จุดหมาย (พิมพ์เองได้)'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'กรุณาระบุจุดหมาย'
                          : null),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('กลับไปแก้ไข')),
          TextButton(
              onPressed: () {
                if (_form.currentState!.validate())
                  Navigator.pop(
                      context, (_title.text.trim(), _destination.text.trim()));
              },
              child: const Text('บันทึก'))
        ],
      );
}
