/// 고지서·계량기 사진 한 장.
/// 새로 촬영하면 base64(아직 S3 미업로드), 저장/복원되면 S3 url 을 가진다.
class BillPhoto {
  final String? base64; // 방금 촬영(S3 미업로드)
  final String? url; // S3 업로드/저장된 공개 URL
  final String media;
  const BillPhoto({this.base64, this.url, this.media = 'image/jpeg'});

  /// DB 에 저장돼 있던 문자열 복원(http면 URL, 아니면 레거시 base64).
  factory BillPhoto.fromStored(String s) => s.startsWith('http') ? BillPhoto(url: s) : BillPhoto(base64: s);
}
